
void execute(String markers = '') {
    try {
        executeInternal(markers)
    } finally {
        collectResults()
    }
}

void collectResults() {
    echo 'Archiving results..'
    archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true, followSymlinks: false
    archiveArtifacts artifacts: '**/tests_*.xml', allowEmptyArchive: true, followSymlinks: false
    junit(
        testResults: '**/tests_*.xml',
        skipOldReports: true,
        skipMarkingBuildUnstable: true
    )
}

private void executeInternal(String markers = '') {
    def retries = -1

    String markersSwitch = ''

    if (markers.trim()) {
        markersSwitch = "-m \"${markers.trim()}\""
    }

    retry("${NUMBER_OF_TESTS_RETRIES}") {
        retries++
        run_in_venv """
            set -o pipefail

            arch_tag=`python -c "import packaging.tags; print(next(packaging.tags.sys_tags()).platform)"`

            # Andromeda tests need an experiment-like path or they fail due to a bug, currently
            # working around this.
            output_dir="fake_experiment-10000/pytest_\${arch_tag}_${retries}"
            log_name="\${output_dir}/pytest.log"
            mkdir -p "\${output_dir}"

            python -m pytest tests \
              ${markersSwitch} \
              --junitxml="\${output_dir}/tests_${retries}.xml" --basetemp="\${output_dir}" --color=yes \
              | tee >(sed 's/\\x1b\\[[0-9;]*m//g' > "\${log_name}")
        """
    }
}
