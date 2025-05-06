// https://q-ai.atlassian.net/jira/projects?page=1&sortKey=key&sortOrder=ASC
import com.qai.JiraConstants

boolean validateJiraConvention(String str) {
    return checkForJiraIssueString(str) && checkForBranchPrefix(str)
}

boolean checkForJiraIssueString(String str) {
    if (str == null) {
        return false
    }

    for (prefix in JiraConstants.JIRA_PROJECT_PREFIXES) {
        def matcher = (str =~ /\b${prefix}-[0-9]+/)
        if (matcher.find()) {
            return true
        }
    }

    return false
}

boolean checkForBranchPrefix(String branchName) {
    if (branchName == null) {
        return false
    }

    for (prefix in JiraConstants.BRANCH_PREFIXES) {
        if (branchName.startsWith(prefix)) {
            return true
        }
    }

    return false
}

boolean checkForSkipString(String contents) {
    if (contents == null) {
        return false
    }

    return contents.split('\n').any { line ->
        line.startsWith(JiraConstants.SKIP_STRING)
    }
}

def call(pullRequest) {
    if (env.CHANGE_ID) {
        if (checkForSkipString(pullRequest.body)) {
            println 'Jira issue conformance test skip string found, skipping check'
            return true
        }

        if (!validateJiraConvention(pullRequest.headRef) &&
            !validateJiraConvention(pullRequest.title)) {
            pullRequest.comment('''\
                **🚫 Branch name is missing Jira issue convention**

                Please use the following convention:
                * `feature/GEN-2028-whatever-string`
                * `bugfix/GEN-1999-something-else`

                Preferably set the branch name or alternatively set as the PR title.

                to skip the check, add the string `NO_BUG` at the start of a line in the PR
                description and rerun the tests.
                '''.stripIndent())
            error('🚫 Branch name is missing Jira issue convention')
            } else {
            println 'Jira issue conformance test passed'
            return true
            }
    }
}
