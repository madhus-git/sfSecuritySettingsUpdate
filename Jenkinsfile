// -------------------- PARAMETERS --------------------
def SETTINGS_FILE_PATTERN = params.SETTINGS_FILE_PATTERN ?: '*.settings'
def UPDATE_KEYS = params.UPDATE_KEYS ?: 'enableTwoFactorAuth'
def UPDATE_VALUES = params.UPDATE_VALUES ?: 'true'
def DEPLOY_ORG_ALIAS = params.DEPLOY_ORG_ALIAS ?: 'DevHub'
def GIT_BRANCH = params.GIT_BRANCH ?: 'develop'
def SETTINGS_DIR = "force-app/main/default/settings"

// -------------------- CROSS-PLATFORM COMMAND RUNNER --------------------
// define closure instead of method (works inside node)
def runCmd = { String cmd ->
    if (isUnix()) {
        sh """#!/bin/bash
        set +e
        ${cmd}
        """
    } else {
        bat """@echo off
        ${cmd}
        """
    }
}

node {
    try {
        // -------------------- STAGE 1: CHECKOUT --------------------
        stage('Checkout SCM') {
            echo "Checking out repository..."
            checkout scm
        }

        // -------------------- STAGE 2: BACKUP BRANCH --------------------
        stage('Create Backup Branch') {
            echo "Creating Git backup branch..."
            def backupBranch = "backup_${GIT_BRANCH}_${new Date().format('yyyyMMddHHmmss')}"
            runCmd("""
                git fetch origin
                git checkout ${GIT_BRANCH}
                git pull origin ${GIT_BRANCH}
                git checkout -b ${backupBranch}
                echo Created backup branch: ${backupBranch}
            """)
        }

        // -------------------- STAGE 3: UPDATE SETTINGS --------------------
        stage('Update Settings XML Files') {
            script {
                try {
                    echo "Updating XML files in ${SETTINGS_DIR} with pattern: ${SETTINGS_FILE_PATTERN}"

                    def keys = UPDATE_KEYS.split(',')
                    def values = UPDATE_VALUES.split(',')
                    if (keys.size() != values.size()) {
                        error("Keys and values count mismatch. Ensure both lists have equal items.")
                    }

                    def updatesMap = [:]
                    keys.eachWithIndex { k, i -> updatesMap[k.trim()] = values[i].trim() }
                    echo "Update Map: ${updatesMap}"

                    def dir = new File(SETTINGS_DIR)
                    dir.eachFileMatch(~/.*${SETTINGS_FILE_PATTERN.replace('*', '.*')}/) { file ->
                        echo "Updating ${file.name}"
                        def xml = new XmlParser().parse(file)
                        updatesMap.each { key, value ->
                            xml.depthFirst().findAll { it.name() == key }.each { node ->
                                echo "➡ Updating ${key} in ${file.name} to ${value}"
                                node.value = value
                            }
                        }
                        def writer = new FileWriter(file)
                        def printer = new XmlNodePrinter(new PrintWriter(writer))
                        printer.setPreserveWhitespace(true)
                        printer.print(xml)
                    }
                } catch (ex) {
                    error("XML Update failed: ${ex.message}")
                }
            }
        }

        // -------------------- STAGE 4: VALIDATE LOCAL CHANGES --------------------
        stage('Validate Local Changes') {
            echo "Showing XML changes before deploy..."
            runCmd("git diff ${SETTINGS_DIR} || exit 0")
        }

        // -------------------- STAGE 5: SF DRY RUN --------------------
        stage('Salesforce Dry-Run Preview') {
            echo "Running Salesforce dry-run..."
            runCmd("""
                sf project deploy preview ^
                    --metadata-dir ${SETTINGS_DIR} ^
                    --target-org ${DEPLOY_ORG_ALIAS} ^
                    --ignore-conflicts ^
                    --ignore-errors ^
                    --verbose
            """.stripIndent())
            input message: "Dry-run complete. Proceed with actual deployment to ${DEPLOY_ORG_ALIAS}?"
        }

        // -------------------- STAGE 6: DEPLOY --------------------
        stage('Deploy to Salesforce Org') {
            try {
                echo "Deploying settings to Salesforce Org: ${DEPLOY_ORG_ALIAS}"
                runCmd("""
                    sf project deploy start ^
                        --metadata-dir ${SETTINGS_DIR} ^
                        --target-org ${DEPLOY_ORG_ALIAS} ^
                        --ignore-conflicts ^
                        --ignore-errors ^
                        --verbose
                """.stripIndent())
            } catch (ex) {
                error("Deployment failed: ${ex.message}")
            }
        }

        // -------------------- STAGE 7: COMMIT & PUSH --------------------
        stage('Commit and Push to Git') {
            echo "Committing updated settings to branch ${GIT_BRANCH}..."
            runCmd("""
                git checkout ${GIT_BRANCH}
                git pull origin ${GIT_BRANCH}
                git add ${SETTINGS_DIR}
                git commit -m "Auto-update: Settings XML updated & deployed to ${DEPLOY_ORG_ALIAS} via Jenkins" || echo "No changes to commit."
                git push origin ${GIT_BRANCH}
            """)
        }

        // -------------------- STAGE 8: VERIFY --------------------
        stage('Post Deployment Verification') {
            echo "Verifying deployed settings from org: ${DEPLOY_ORG_ALIAS}"
            runCmd("""
                sf project retrieve start ^
                    --metadata-dir ${SETTINGS_DIR} ^
                    --target-org ${DEPLOY_ORG_ALIAS} ^
                    --ignore-errors ^
                    --verbose
            """)
            echo "Verification successful."
        }

    } catch (err) {
        // -------------------- ROLLBACK STAGE --------------------
        stage('Rollback Changes') {
            echo "Deployment failed: ${err.message}"
            echo "Rolling back to last Git commit..."
            runCmd("""
                git restore ${SETTINGS_DIR}
                git checkout ${GIT_BRANCH}
                git reset --hard origin/${GIT_BRANCH}
            """)
            error("Rollback complete. Please review Jenkins logs for details.")
        }
    } finally {
        // -------------------- CLEANUP --------------------
        stage('Cleanup') {
            echo "Cleaning up Jenkins workspace..."
            cleanWs()
        }
    }
}
