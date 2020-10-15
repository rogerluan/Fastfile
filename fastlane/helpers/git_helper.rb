# This class is a collection of utility methods that help with git-related tasks, such as extracting the PR number, title, and author from the environment variables, and fetching the remote URL of the repository.
#
# It also contains methods to fetch the current branch, the commit hash, and the commit message, among others.
#
# Wherever there are lists of env vars for specific CI/CD services, the goal is to add more providers as needed.
class GitHelper
  # The Remote URL taken from the local git repository settings.
  # The URL can be either in the HTTPS or SSH format, e.g. "https://github.com/acmeinc/iOS.git" or "git@github.com:acmeinc/iOS.git", respectively.
  def self.repo_remote_url
    git.remotes.first.url
  end

  # The repository organization, e.g. "acmeinc" in "https://github.com/acmeinc/iOS"
  def self.repo_org
    @repo_org ||= repo_remote_url[git_repo_regex, 1]
  end

  # The repository name, e.g. "iOS" in "https://github.com/acmeinc/iOS"
  def self.repo_name
    @repo_name ||= repo_remote_url[git_repo_regex, 2]
  end

  # The repository organization and name, joined by a forward slash, e.g. "acmeinc/iOS"
  def self.repo_slug
    "#{repo_org}/#{repo_name}"
  end

  # The number of the PR, e.g. "9001"
  def self.pr_number
    pull_request_number_env_var_candidates = [
      "BITRISE_PULL_REQUEST", # Bitrise
      "CHANGE_ID", # Jenkins
    ]
    first_env_var_value_or_nil(pull_request_number_env_var_candidates)
  end

  # The link to the PR, e.g. "https://github.com/acmeinc/iOS/pull/9001"
  def self.pr_link
    pull_request_link_env_var_candidates = [
      "CHANGE_URL", # Jenkins
    ]
    first_env_var_value_or_nil(pull_request_link_env_var_candidates) || "https://github.com/#{repo_slug}/pull/#{pr_number}"
  end

  # The title of the PR, e.g. "[Tools] Integrate fastlane"
  def self.pr_title
    pull_request_title_env_var_candidates = [
      "BITRISE_GIT_MESSAGE", # Bitrise - May be the commit message instead of the PR title
      "CHANGE_TITLE", # Jenkins
    ]
    first_env_var_value_or_nil(pull_request_title_env_var_candidates)
  end

  # The display name of the author of the PR e.g. "Roger Oba"
  # Note: This method is not guaranteed to return the correct value in all CI/CD services. Sometimes it might return the name of the last committer instead of the PR author.
  def self.pr_author_display_name
    pull_request_author_display_name_env_var_candidates = [
      "GIT_CLONE_COMMIT_AUTHOR_NAME", # Bitrise
      "CHANGE_AUTHOR_DISPLAY_NAME", # Jenkins
    ]
    first_env_var_value_or_nil(pull_request_author_display_name_env_var_candidates) || `git log -1 --pretty=format:'%an'`
  end

  # The username of the author of the PR, if available, e.g. "rogerluan"
  def self.pr_author_username
    pull_request_author_username_env_var_candidates = [
      "CHANGE_AUTHOR", # Jenkins
    ]
    first_env_var_value_or_nil(pull_request_author_username_env_var_candidates)
  end

  # The name of the current branch, e.g. "roger/integrate-fastlane"
  def self.current_branch
    Fastlane::Actions.git_branch
  end

  # The hash of the current commit in its full form, e.g. "f3cdc2d707fefd2e35bc16e8b379779a16c25fed"
  def self.commit_hash
    git_commit_env_var_candidates = [
      "BITRISE_GIT_COMMIT", # Bitrise
      "GIT_COMMIT", # Jenkins
    ]
    first_env_var_value_or_nil(git_commit_env_var_candidates) || `git show -s --format=%H`.strip
  end

  # The commit hash of the base branch, in its full form, e.g. "f3cdc2d707fefd2e35bc16e8b379779a16c25fed`
  # It fetches the latest commit from remote.
  # Pass the base branch name as an argument, e.g. `base_commit_hash(base_branch: "main")`. Defaults to "main".
  def self.base_commit_hash(base_branch: "main")
    `git ls-remote #{repo_remote_url} --heads refs/heads/#{base_branch} | cut -f 1`.strip
  end

  # The commit message of the current commit, e.g. `Dump all env vars.`
  def self.commit_message
    commit_message = `git log --pretty=oneline #{commit_hash} | grep #{commit_hash}`
    commit_message[commit_hash] = "" # Removes an annoying prefix
    commit_message.strip
  end

  # The datetime string of the current commit, e.g. `Mon May 23 20:09:38 2022 +0000`
  def self.commit_datetime
    `git show --no-patch --no-notes --pretty='%cd' #{commit_hash}`.strip
  end

  private

  def self.git
    @git ||= Git.open("..")
  end

  # The first captured group is the repo org, and the second is the repo name.
  # This accepts both HTTPS and SSH repo strings, as long as they end with ".git".
  def self.git_repo_regex
    %r{(?:.*)[:|/]([\w-]+)/(.*)\.git}
  end

  # Finds the first env var that is not nil or empty and return it. If none is found, return nil.
  def self.first_env_var_value_or_nil(env_var_names)
    env_var_names.each do |env_var_name|
      value = ENV[env_var_name]
      return value unless value.to_s.empty?
    end
    nil
  end
end
