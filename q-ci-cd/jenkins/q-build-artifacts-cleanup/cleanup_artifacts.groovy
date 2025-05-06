@Grab('org.kohsuke:github-api:1.305')
import org.kohsuke.github.*
import groovy.json.JsonSlurper
import java.nio.file.*

def GITHUB_ORG = System.getenv("GITHUB_ORG") 
def GITHUB_TOKEN = System.getenv("GITHUB_TOKEN") 
def ARTIFACTS_DIR = System.getenv("ARTIFACTS_DIR") 

// Function to get PR status
def getPrStatus(String project, String prNumber) {
    def repo = "${GITHUB_ORG}/${project}"
    def url = new URL("https://api.github.com/repos/${repo}/pulls/${prNumber}")
    def connection = url.openConnection()
    connection.setRequestProperty("Authorization", "token ${GITHUB_TOKEN}")
    connection.setRequestMethod("GET")

    if (connection.responseCode == 200) {
        def response = new JsonSlurper().parse(connection.inputStream)
        return response.state.toUpperCase() // OPEN, CLOSED, MERGED
    } else {
        println "Warning: PR ${prNumber} for ${project} not found (HTTP ${connection.responseCode}) (${url})"
        return null
    }
}

// Function to clean artifacts
def cleanArtifacts() {
    File artifactsRoot = new File(ARTIFACTS_DIR)
    File[] projects = artifactsRoot.listFiles().findAll { it.isDirectory() }
    for (File project : projects) {
        def projectName = project.name
        println "Project Name: ${projectName}"
        File[] pullRequests = project.listFiles().findAll { it.isDirectory() }
        for (File prDir : pullRequests) {
            def prNumber = prDir.name.replace("PR-", "")
            println "PR Number: ${prNumber}"
            if (!prNumber.isNumber()) {
                println "Skipping invalid PR directory: ${prDir.name}"
                continue
            }

            def prStatus = getPrStatus(projectName, prNumber)
            if (prStatus in ["CLOSED", "MERGED"]) {
                println "Deleting artifacts for ${projectName} - PR ${prNumber} (${prStatus})"
                prDir.deleteDir()
            } else {
                println "PR ${prNumber} for ${projectName} is still open. Keeping artifacts."
            }
        }
    }
}


return this