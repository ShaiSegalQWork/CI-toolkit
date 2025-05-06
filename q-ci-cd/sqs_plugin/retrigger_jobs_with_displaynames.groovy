import jenkins.model.*
import hudson.model.*

//def jobName = "SQS Audio Features Runner"
//def jobName = "SQS Audio Transcriptions Runner"
//def jobName = "SQS Q-Features Runner"
//def jobName = "SQS Session Data Runner"
//def jobName = "SQS Orion Runner"
//def jobName = "SQS Session Metadata Runner"
def job = Jenkins.instance.getItemByFullName(jobName)

def displayNamesToRetrigger = <displayName array>

def jenkinsUrl = Jenkins.instance.getRootUrl()

job.builds.findAll { 
 it.displayName in displayNamesToRetrigger && (it.result == Result.FAILURE || it.result == null)
}.each { failedBuild ->
    def paramsAction = failedBuild.getAction(hudson.model.ParametersAction)
    def parameters = paramsAction ? paramsAction.parameters.collect { 
        new hudson.model.StringParameterValue(it.name, it.value as String)
    } : []

    job.scheduleBuild2(0, new hudson.model.ParametersAction(parameters))
}

println("Check the Jenkins build queue for all scheduled builds.")
