import io.jenkins.plugins.sqs.*
import jenkins.model.*

AllTriggers allTriggers = AllTriggers.INSTANCE
List<SqsTrigger> triggerList = allTriggers.getAll()

if (triggerList.isEmpty()) {
    println "No SQS Triggers found in the Jenkins environment."
} else {
    println "Listing all current SQS Triggers:"
    triggerList.each { trigger ->
        println " - SQS Trigger: ${trigger}"
        println "   Queue URL: ${trigger.sqsTriggerQueueUrl}"
        println "   Credentials ID: ${trigger.sqsTriggerCredentialsId}"
        println "   Disable Concurrent Builds: ${trigger.sqsDisableConcurrentBuilds}"
    }
}
