# typed: true
module Braid
  class Command
    extend T::Sig

    class InvalidRevision < BraidError
    end

    extend Operations::VersionControl
    include Operations::VersionControl

    def self.run(command, *args)
      verify_git_version!
      check_working_dir!

      klass = Commands.const_get(command.to_s)
      klass.new.run(*args)

    rescue BraidError => error
      case error
        when Operations::ShellExecutionError
          msg "Shell error: #{error.message}"
        else
          msg "Error: #{error.message}"
      end
      exit(1)
    end

    sig {params(str: String).void}
    def self.msg(str)
      puts "Braid: #{str}"
    end

    sig {params(str: String).void}
    def msg(str)
      self.class.msg(str)
    end

    def config
      @config ||= Config.new({'mode' => config_mode})
    end

    sig {returns(T::Boolean)}
    def verbose?
      Braid.verbose
    end

    sig {returns(T::Boolean)}
    def force?
      Braid.force
    end

    private

    sig {returns(Config::ConfigMode)}
    def config_mode
      Config::MODE_MAY_WRITE
    end

    def setup_remote(mirror)
      existing_force = Braid.force
      begin
        Braid.force = true
        Command.run(:Setup, mirror.path)
      ensure
        Braid.force = existing_force
      end
    end

    def clear_remote(mirror, options)
      git.remote_rm(mirror.remote) unless options['keep']
    end

    sig {returns(T::Boolean)}
    def use_local_cache?
      Braid.use_local_cache
    end

    sig {void}
    def self.verify_git_version!
      git.require_version!(REQUIRED_GIT_VERSION)
    end

    sig {void}
    def self.check_working_dir!
      # If we aren't in a git repository at all, git.is_inside_worktree will
      # propagate a "fatal: Not a git repository" ShellException.
      unless git.is_inside_worktree
        raise BraidError, 'Braid must run inside a git working tree.'
      end
      if git.relative_working_dir != ''
        raise BraidError, 'Braid does not yet support running in a subdirectory of the working tree.'
      end
    end

    sig {void}
    def bail_on_local_changes!
      git.ensure_clean!
    end

    def with_reset_on_error
      bail_on_local_changes!

      work_head = git.head

      begin
        yield
      rescue => error
        msg "Resetting to '#{work_head[0, 7]}'."
        git.reset_hard(work_head)
        raise error
      end
    end

    sig {void}
    def add_config_file
      git.rm(OLD_CONFIG_FILE) if File.exist?(OLD_CONFIG_FILE)
      git.add(CONFIG_FILE)
    end

    def display_revision(mirror, revision = nil)
      revision ||= mirror.revision
      "'#{revision[0, 7]}'"
    end

    def determine_repository_revision(mirror)
      if mirror.tag
        if use_local_cache?
          Dir.chdir git_cache.path(mirror.url) do
            # Dereference the tag to a commit since we want the `revision`
            # attribute of a mirror to always be a commit object.  This is also
            # currently needed because we don't fetch annotated tags into the
            # downstream repository, although we might change that in the
            # future.
            git.rev_parse(mirror.local_ref + "^{commit}")
          end
        else
          raise BraidError, 'unable to retrieve tag version when cache disabled.'
        end
      else
        git.rev_parse(mirror.local_ref + "^{commit}")
      end
    end

    def validate_new_revision(mirror, revision)
      if revision.nil?
        determine_repository_revision(mirror)
      else
        new_revision = git.rev_parse(revision + "^{commit}")

        if new_revision == mirror.revision
          raise InvalidRevision, 'mirror is already at requested revision'
        end

        new_revision
      end
    end
  end
end
