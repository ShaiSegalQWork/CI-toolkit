import hudson.model.*
import jenkins.model.*
import io.jenkins.plugins.sqs.*

// Specify the job name you want to modify
def jobName = 'SQS Session Metadata Dispatcher'

// Retrieve the job from Jenkins
def job = Jenkins.instance.getItemByFullName(jobName)

if (job instanceof FreeStyleProject) {
    println "Modifying job: ${job.name}"
    
    // Get all triggers associated with this job
    AllTriggers allTriggers = AllTriggers.INSTANCE
    List<SqsTrigger> triggerList = allTriggers.getAll()

    // Find and remove the specific SQS trigger
    def triggerToRemove = triggerList.find { trigger ->
        trigger.sqsTriggerQueueUrl == 'https://sqs.us-east-1.amazonaws.com/608104255617/session-metadata' &&
        trigger.sqsTriggerCredentialsId == 'Jenkins_Service_Account_AWS_AKI_SAK_Q'
    }

    if (triggerToRemove != null) {
        allTriggers.remove(triggerToRemove)
        println "Removed SQS Trigger: ${triggerToRemove} from job '${job.name}'."
    } else {
        println "No matching SQS Trigger found for removal in job '${job.name}'."
    }

    // Save the job configuration
    job.save()
} else {
    println "Job '${jobName}' is not a FreeStyle project."
}
