
def success() {
    slackSend(channel: 'C05LB9KD9U7', message: "BUILD: ${env.JOB_NAME} number ${env.BUILD_ID} succeeded \nURL: ${env.RUN_DISPLAY_URL}", token: 'Slack-Bot', color: 'good')
}

def failure(currentBuild) {
    List<String> logLines = currentBuild.rawBuild.getLog(Integer.MAX_VALUE)
    List<String> keywordPatterns = ['error', 'fail', 'failed', 'failure']
    List<Integer> errorIndices = []
    int contextLines = 10

    String keywordRegex = keywordPatterns.collect { pattern -> "\\b${pattern}\\b" }.join('|')
    for (int i = 0; i < logLines.size(); i++) {
        String line = logLines[i].toLowerCase()

        boolean containsKeyword = (line =~ /${keywordRegex}/).find()

        List<String> unwantedPhrases = ['Seen branch in repository', 'skipped due to earlier', 'git rev-parse', 'Merging Revision', 'Failed in branch', '[Pipeline]']
        boolean doesNotContainUnwantedPhrases = unwantedPhrases.every { phrase -> !logLines[i].contains(phrase) }

        if (containsKeyword && doesNotContainUnwantedPhrases) {
            errorIndices.add(i)
        }
    }

    Set<Integer> relevantLines = [] as Set
    for (int index : errorIndices) {
        int startLine = Math.max(0, index - contextLines)
        int endLine = Math.min(logLines.size() - 1, index + contextLines)
        for (int i = startLine; i <= endLine; i++) {
            relevantLines.add(i)
        }
    }

    Closure<Void> createAndPostComment = { String logContent ->
        String comment = """\
                            |### 🚫 Failed building PR
                            |
                            |**Build**: ${env.JOB_NAME} #${env.BUILD_ID}
                            |**URL**: ${env.RUN_DISPLAY_URL}
                            |**Logs**:
                            |
                            |<details><summary>Pipeline Log</summary>
                            |
                            |```
                            |${logContent}
                            |```
                            |
                            |</details>
                            """.stripMargin()
        pullRequest.comment(comment)
    }

    slackSend(channel: 'C05LB9KD9U7', message: "BUILD: ${env.JOB_NAME} number ${env.BUILD_ID} failed \nURL: ${env.RUN_DISPLAY_URL}", token: 'Slack-Bot', color: 'danger')

    if (env.CHANGE_ID == null) {
        echo 'This is not a PR build. Skipping comment creation.'
        return
    }

    if (relevantLines.isEmpty()) {
        String buildLog = currentBuild.rawBuild.getLog(100).join('\n')
        createAndPostComment(buildLog)
    } else {
        String inferredErrorLog = relevantLines
            .findAll { index -> !logLines[index].contains('[Pipeline]') }
            .collect { index -> logLines[index] }
            .join('\n')
        createAndPostComment(inferredErrorLog)
    }

}

def always(Set usedNodeLabels) {
    usedNodeLabels.each { label ->
        node("${label}") {
            echo "Cleaning workspace on node ${label}"
            cleanWs(cleanWhenNotBuilt: false, deleteDirs: true, disableDeferredWipeout: true, notFailBuild: false)
        }
    }
}
