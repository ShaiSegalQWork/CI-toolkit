
def checkIfFileIsEmpty(String fileName) {
    return sh(script: """if [ ! -s ${fileName}.txt ]; then echo "true"; else echo "false"; fi""", returnStdout: true).trim()
}

def call() {
    sh '''
        git diff HEAD^1 HEAD --diff-filter=d --name-only -- '*.py' | grep -vf .diff-ignore > python_changed_files.txt || true
        git diff HEAD^1 HEAD --diff-filter=d --name-only -- '*.h' '*.cpp' '*.hpp' '*.c' | grep -vf .diff-ignore > clang_changed_files.txt || true
        git diff HEAD^1 HEAD --diff-filter=d --name-only | grep -vf .diff-ignore > changed_files.txt || true
    '''

    def clang_is_empty = checkIfFileIsEmpty('clang_changed_files')
    def python_is_empty = checkIfFileIsEmpty('python_changed_files')
    def changed_files_is_empty = checkIfFileIsEmpty('changed_files')

    env.RUN_CLANG_CHECKS = clang_is_empty == 'false' ? 'true' : 'false'
    env.RUN_PYTHON_CHECKS = python_is_empty == 'false' ? 'true' : 'false'
    env.RUN_PRE_COMMIT = changed_files_is_empty == 'false' ? 'true' : 'false'
}
