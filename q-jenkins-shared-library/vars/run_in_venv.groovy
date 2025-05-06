def run_in_venv(venvPath, inner) {
    if (isUnix()) {
        // Keep this in the first line with quotes, otherwise this will not be bash
        sh """#!/bin/bash
            set -o errexit
            . ${venvPath}/bin/activate
            ${inner}
        """
    } else {
        msys2_bash """
            . ${venvPath}/Scripts/activate
            ${inner}
        """
    }
}

def call(Closure scriptBody) {
    def commands = scriptBody()
    venvPath = './venv'
    if (env.VENV_PATH) {
        echo "Overriding venvPath with ${env.VENV_PATH}"
        venvPath = env.VENV_PATH
    }
    run_in_venv(venvPath, commands)
}

def call(String script) {
    venvPath = './venv'
    if (env.VENV_PATH) {
        echo "Overriding venvPath with ${env.VENV_PATH}"
        venvPath = env.VENV_PATH
    }
    run_in_venv(venvPath, script)
}
