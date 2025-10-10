// ================================
// Scripted Jenkins Pipeline (Secure JWT Auth via Jenkins Credentials)
// Enhanced: /backups folder, auto absolute XML path, tag comparison, tag-level change summary
// ================================
node {

    properties([
        parameters([
            string(name: 'OrgAlias', defaultValue: '', description: '* Salesforce Org Alias / Username'),
            string(name: 'OrgUrl', defaultValue: 'https://login.salesforce.com', description: '* Salesforce Org URL'),
            string(name: 'XMLFilePath', defaultValue: '', description: '* Path to XML file to update (e.g. force-app/main/default/settings/Security.settings-meta.xml)'),
            string(name: 'TagNames', defaultValue: '', description: '* Comma-separated XML tag names (e.g. tag1,tag2)'),
            string(name: 'TagValues', defaultValue: '', description: '* Comma-separated XML tag values (e.g. value1,value2)'),
            string(name: 'BranchName', defaultValue: '', description: '* Git branch to push changes (e.g. devOrg)')
        ])
    ])

    def ORG_ALIAS = params.OrgAlias?.trim()
    def ORG_URL = params.OrgUrl?.trim()
    def XML_PATH = params.XMLFilePath?.trim()
    def TAG_NAMES = params.TagNames?.trim()
    def TAG_VALUES = params.TagValues?.trim()
    def GIT_BRANCH = params.BranchName?.trim()
    def BACKUP_DIR = "backups/backup_${env.BUILD_ID}"
    def xmlFileName = XML_PATH.tokenize('/').last()
    def backupFile = "${BACKUP_DIR}/${xmlFileName}"

    try {
        // -------------------------------
        // Validate mandatory parameters
        // -------------------------------
        if (!ORG_ALIAS) error "OrgAlias is mandatory"
        if (!ORG_URL) error "OrgUrl is mandatory"
        if (!XML_PATH) error "XMLFilePath is mandatory"
        if (!TAG_NAMES) error "TagNames is mandatory"
        if (!TAG_VALUES) error "TagValues is mandatory"
        if (!GIT_BRANCH) error "BranchName is mandatory"

        def tagList = TAG_NAMES.split(',').collect { it.trim() }
        def valueList = TAG_VALUES.split(',').collect { it.trim() }
        if (tagList.size() != valueList.size()) {
            error "Number of TagNames (${tagList.size()}) must match TagValues (${valueList.size()})"
        }

        // -------------------------------
        // Checkout code
        // -------------------------------
        stage('Checkout Code') {
            echo "Checking out source code..."
            checkout scm
        }

        // -------------------------------
        // Ensure XML path is absolute (workspace-aware)
        // -------------------------------
        if (!XML_PATH.startsWith('/') && !XML_PATH.matches('^[A-Za-z]:.*')) {
            XML_PATH = "${env.WORKSPACE}/${XML_PATH}"
        }
        if (!isUnix()) {
            XML_PATH = XML_PATH.replace('/', '\\')
            BACKUP_DIR = BACKUP_DIR.replace('/', '\\')
            backupFile = backupFile.replace('/', '\\')
        }

        echo "Resolved XML Path: ${XML_PATH}"
        echo "Backup Directory: ${BACKUP_DIR}"

        // -------------------------------
        // Backup XML under /backups
        // -------------------------------
        stage('Backup XML to /backups') {
            echo "Creating backup folder under repo: ${BACKUP_DIR}"
            if (isUnix()) {
                sh """
                    mkdir -p "${BACKUP_DIR}"
                    cp "${XML_PATH}" "${backupFile}"
                """
            } else {
                bat """
                    if not exist "${BACKUP_DIR}" mkdir "${BACKUP_DIR}"
                    if exist "${XML_PATH}" (
                        copy /Y "${XML_PATH}" "${BACKUP_DIR}\\"
                    ) else (
                        echo XML file not found: ${XML_PATH}
                        exit /b 1
                    )
                """
            }
            echo "Backup created at: ${backupFile}"
        }

        // -------------------------------
        // Read and update XML tags
        // -------------------------------
        stage('Update XML Tags and Show Changes') {
            def xmlContent = readFile(XML_PATH)

            for (int i = 0; i < tagList.size(); i++) {
                def tag = tagList[i]
                def newValue = valueList[i]
                def pattern = /<${tag}>(.*?)<\/${tag}>/
                def matcher = (xmlContent =~ pattern)
                if (matcher) {
                    def oldValue = matcher[0][1]
                    echo "Tag <${tag}> — Old: ${oldValue} → New: ${newValue}"
                    xmlContent = xmlContent.replaceAll(pattern, "<${tag}>${newValue}</${tag}>")
                } else {
                    echo "Tag <${tag}> not found in XML — skipping"
                }
            }

            writeFile(file: XML_PATH, text: xmlContent)
        }

        // -------------------------------
        // Detect XML differences (tag-level summary)
        // -------------------------------
        stage('Detect XML Changes') {
            def diffOutput = ""
            if (isUnix()) {
                diffOutput = sh(script: "diff \"${backupFile}\" \"${XML_PATH}\" || true", returnStdout: true).trim()
            } else {
                diffOutput = bat(script: "fc \"${backupFile}\" \"${XML_PATH}\" || exit /b 0", returnStdout: true).trim()
            }

            if (!diffOutput) {
                echo "✅ No changes detected — skipping commit and deploy."
                currentBuild.result = 'SUCCESS'
                return
            }

            echo "🔍 Changes detected — analyzing tag differences..."

            // Extract changed XML lines and show before/after for tags
            def tagDiffs = []
            def tagPattern = /<(\w+)>(.*?)<\/\1>/
            def lines = diffOutput.readLines()

            String currentTag = ""
            String beforeValue = ""
            String afterValue = ""

            for (line in lines) {
                if (line.startsWith("*****")) continue
                def m = line =~ tagPattern
                if (m.find()) {
                    currentTag = m[0][1]
                    if (line.contains("BACKUP_") || line.trim().startsWith("<")) {
                        beforeValue = m[0][2]
                    } else if (line.contains("WORKSPACE") || line.trim().startsWith("<")) {
                        afterValue = m[0][2]
                    }
                    if (beforeValue && afterValue) {
                        tagDiffs << [tag: currentTag, oldVal: beforeValue, newVal: afterValue]
                        beforeValue = ""
                        afterValue = ""
                    }
                }
            }

            if (tagDiffs) {
                echo "🧾 Tag-level changes summary:"
                tagDiffs.each { diff ->
                    echo "  • <${diff.tag}>: '${diff.oldVal}' → '${diff.newVal}'"
                }
            } else {
                echo "⚠️ No tag-level changes could be parsed. Raw diff output below:"
                echo diffOutput.take(1000)
            }
        }

        // -------------------------------
        // Commit & push both XML and backup
        // -------------------------------
        stage('Commit and Push Changes to GitHub') {
            echo "Pushing updated XML and backup to branch: ${GIT_BRANCH}"
            if (isUnix()) {
                sh """
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git checkout -B ${GIT_BRANCH}
                    git add "${XML_PATH}" "${BACKUP_DIR}"
                    git commit -m "Updated ${xmlFileName} and created backup (build #${env.BUILD_ID})" || echo "No changes to commit"
                    git push -u origin ${GIT_BRANCH}
                """
            } else {
                bat """
                    git checkout -B ${GIT_BRANCH}
                    git add "${XML_PATH}" "${BACKUP_DIR}"
                    git commit -m "Updated ${xmlFileName} and created backup (build #${env.BUILD_ID})" || echo No changes to commit
                    git push -u origin ${GIT_BRANCH}
                """
            }
            echo "Backup and updated XML pushed to GitHub branch: ${GIT_BRANCH}"
            echo "View backups at: https://github.com/madhus-git/sfSecuritySettingsUpdate/tree/${GIT_BRANCH}/backups"
        }

        // -------------------------------
        // Salesforce authentication & deploy
        // -------------------------------
        stage('Authenticate & Deploy to Salesforce') {
            echo "Authenticating Salesforce Org: ${ORG_ALIAS}"
            withCredentials([
                string(credentialsId: 'sfdc-consumer-key', variable: 'CONNECTED_APP_CONSUMER_KEY'),
                string(credentialsId: 'sfdc-username', variable: 'SFDC_USERNAME'),
                file(credentialsId: 'sfdc-jwt-key', variable: 'JWT_KEY_FILE')
            ]) {
                if (isUnix()) {
                    sh """
                        sf org login jwt \
                            --client-id ${CONNECTED_APP_CONSUMER_KEY} \
                            --jwt-key-file ${JWT_KEY_FILE} \
                            --username ${SFDC_USERNAME} \
                            --alias ${ORG_ALIAS} \
                            --instance-url ${ORG_URL}
                    """
                } else {
                    bat """
                        sf org login jwt ^ 
                            --client-id %CONNECTED_APP_CONSUMER_KEY% ^ 
                            --jwt-key-file %JWT_KEY_FILE% ^ 
                            --username %SFDC_USERNAME% ^ 
                            --alias %OrgAlias% ^ 
                            --instance-url ${ORG_URL}
                    """
                }
            }

            echo "Deploying updated XML file to Salesforce Org: ${ORG_ALIAS}"
            if (isUnix()) {
                sh "sf project deploy start --target-org ${ORG_ALIAS} --source-dir \"${XML_PATH}\" --wait 10"
            } else {
                bat "sf project deploy start --target-org %OrgAlias% --source-dir \"${XML_PATH}\" --wait 10"
            }
        }

    } catch (err) {
        echo "❌ Error encountered: ${err}"
        currentBuild.result = 'FAILURE'
        throw err
    } finally {
        stage('Clean Workspace') {
            echo "Cleaning workspace..."
            cleanWs()
        }
    }
}
