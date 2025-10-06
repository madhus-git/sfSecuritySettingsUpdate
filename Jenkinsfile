// -------------------- BUILD PARAMETERS --------------------
properties([
    parameters([
        string(name: 'SETTINGS_FILE_PATTERN', defaultValue: '*.settings-meta.xml', description: 'Pattern of Settings XML files (e.g. Security.settings-meta.xml or *.settings-meta.xml)'),
        string(name: 'UPDATE_KEYS', defaultValue: 'canUsersGrantLoginAccess,enableAdminLoginAsAnyUser', description: 'Comma-separated XML element keys to update'),
        string(name: 'UPDATE_VALUES', defaultValue: 'true,false', description: 'Comma-separated values for each key (match order with UPDATE_KEYS)'),
        choice(name: 'DEPLOY_ORG', choices: ['dev', 'sit', 'uat', 'prod'], description: 'Salesforce Org environment to deploy'),
        string(name: 'GIT_BRANCH', defaultValue: 'devOrg', description: 'Git branch to update and push')
    ])
])

// -------------------- READ PARAMETERS --------------------
def SETTINGS_FILE_PATTERN = params.SETTINGS_FILE_PATTERN
def UPDATE_KEYS = params.UPDATE_KEYS
def UPDATE_VALUES = params.UPDATE_VALUES
def DEPLOY_ORG = params.DEPLOY_ORG
def GIT_BRANCH = params.GIT_BRANCH
def SETTINGS_DIR = "force-app/main/default/settings"

// Map Org name to Salesforce CLI alias
def ORG_ALIAS_MAP = [
    'dev': 'DevOrg',
    'sit': 'SitOrg',
    'uat': 'UatOrg',
    'prod': 'ProdOrg'
]
def DEPLOY_ORG_ALIAS = ORG_ALIAS_MAP[DEPLOY_ORG]

// -------------------- CROSS-PLATFORM COMMAND EXECUTION --------------------
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

        // -------------------- STAGE 2: CREATE BACKUP BRANCH --------------------
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

        // -------------------- STAGE 3: UPDATE SETTINGS XML FILES (SANDBOX-SAFE) --------------------
        stage('Update Settings XML Files') {
            script {
                try {
                    echo "Updating XML files in ${SETTINGS_DIR} with pattern: ${SETTINGS_FILE_PATTERN}"

                    // Prepare key-value map
                    def keys = UPDATE_KEYS.split(',')
                    def values = UPDATE_VALUES.split(',')
                    if (keys.size() != values.size()) {
                        error("Keys and values count mismatch. Ensure both lists have equal items.")
                    }
                    def updatesMap = [:]
                    keys.eachWithIndex { k, i -> updatesMap[k.trim()] = values[i].trim() }
                    echo "Update Map: ${updatesMap}"

                    // -------------------- SANDBOX-SAFE FILE DISCOVERY --------------------
                    def filesToUpdate = []

                    dir(SETTINGS_DIR) {
                        // List all files in settings directory
                        def fileNames = sh(script: "ls", returnStdout: true).trim().split("\n")
                        def pattern = SETTINGS_FILE_PATTERN.replace("*", ".*") // simple regex

                        for (f in fileNames) {
                            if (f == SETTINGS_FILE_PATTERN || f.matches(pattern)) {
                                filesToUpdate << "${SETTINGS_DIR}/${f}"
                            }
                        }
                    }

                    if (filesToUpdate.isEmpty()) {
                        error("No files found matching pattern ${SETTINGS_FILE_PATTERN} in ${SETTINGS_DIR}")
                    }

                    // -------------------- UPDATE EACH FILE --------------------
                    for (f in filesToUpdate) {
                        echo "Processing ${f}"
                        def content = readFile(f)
                        def xml = new XmlParser().parseText(content)

                        updatesMap.each { key, value ->
                            def updated = false
                            xml.depthFirst().findAll { it.name() == key }.each { node ->
                                echo "➡ Updating ${key} in ${f} to ${value}"
                                node.value = value
                                updated = true
                            }
                            if (!updated) {
                                echo "⚠ Warning: Key '${key}' not found in ${f}"
                            }
                        }

                        def writer = new StringWriter()
                        def printer = new XmlNodePrinter(new PrintWriter(writer))
                        printer.setPreserveWhitespace(true)
                        printer.print(xml)
                        writeFile file: f, text: writer.toString()
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

        // -------------------- STAGE 5: SF DRY-RUN PREVIEW --------------------
        stage('Salesforce Dry-Run Preview') {
            echo "Running Salesforce dry-run to validate deployment..."
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
            echo "Deploying settings to Salesforce Org: ${DEPLOY_ORG_ALIAS}"
            runCmd("""
                sf project deploy start ^
                    --metadata-dir ${SETTINGS_DIR} ^
                    --target-org ${DEPLOY_ORG_ALIAS} ^
                    --ignore-conflicts ^
                    --ignore-errors ^
                    --verbose
            """.stripIndent())
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

        // -------------------- STAGE 8: POST-DEPLOY VERIFICATION --------------------
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
        // -------------------- ROLLBACK --------------------
        stage('Rollback Changes') {
            echo "Deployment failed: ${err.message}"
            echo "Rolling back local changes..."
            runCmd("""
                git restore ${SETTINGS_DIR}
                git checkout ${GIT_BRANCH}
                git reset --hard origin/${GIT_BRANCH}
            """)
            error("Rollback complete. Review Jenkins logs for details.")
        }
    } finally {
        // -------------------- CLEANUP --------------------
        stage('Cleanup') {
            echo "Cleaning up Jenkins workspace..."
            cleanWs()
        }
    }
}
