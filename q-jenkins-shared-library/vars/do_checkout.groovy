def checkout_merge(String PROJECT_NAME, String GIT_REPO_ADDRESS) {
    checkout(
        [
            $class: 'GitSCM',
            branches: [[name: "${env.CHANGE_BRANCH}"]],
            doGenerateSubmoduleConfigurations: false,
            extensions: [
                [$class: 'CleanBeforeCheckout'],
                [$class: 'RelativeTargetDirectory', relativeTargetDir : "${PROJECT_NAME}"],
                [
                    $class: 'PreBuildMerge',
                    options: [
                        fastForwardMode: 'NO_FF',
                        mergeRemote: 'origin',
                        mergeStrategy: 'default',
                        mergeTarget: "${env.CHANGE_TARGET}"
                    ]
                ],
                [
                    $class: 'UserIdentity',
                    email: 'jenkins@q.ai',
                    name: 'jenkins'
                ]
            ],
            submoduleCfg: [],
            userRemoteConfigs: [[credentialsId: 'Jenkins-Master-User', url: "${GIT_REPO_ADDRESS}"]],
        ]
    )
}

def checkout_branch(String PROJECT_NAME, String GIT_REPO_ADDRESS) {
    checkout(
        [
            $class: 'GitSCM',
            branches: [[name: "${env.BRANCH_NAME}"]],
            doGenerateSubmoduleConfigurations: false,
            extensions: [
                [$class: 'CleanBeforeCheckout'],
                [$class: 'RelativeTargetDirectory', relativeTargetDir : "${PROJECT_NAME}"]
            ],
            submoduleCfg: [],
            userRemoteConfigs: [[credentialsId: 'Jenkins-Master-User', url: "${GIT_REPO_ADDRESS}"]],
        ]
    )
}

def call(String PROJECT_NAME, String GIT_REPO_ADDRESS) {
    if (env.CHANGE_ID) {
        echo "This is a PR build. PR ID: ${env.CHANGE_ID}"
        checkout_merge(PROJECT_NAME, GIT_REPO_ADDRESS)
    } else {
        echo 'This is not a PR build (e.g., branch build or tag build)'
        checkout_branch(PROJECT_NAME, GIT_REPO_ADDRESS)
    }
}

