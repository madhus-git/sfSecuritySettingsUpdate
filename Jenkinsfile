pipeline {
    agent any
    parameters {
        string(name: 'ORG_ALIAS', defaultValue: '', description: 'Salesforce Org Alias')
        string(name: 'XML_FILE', defaultValue: 'force-app/main/default/settings/Security.settings-meta.xml', description: 'Path to XML file')
        text(name: 'TAGS_MAP', defaultValue: 'canUsersGrantLoginAccess=false\nenableAdminLoginAsAnyUser=true', description: 'Tags and values to update (format: tag=value, one per line)')
    }
    environment {
        LOG_DIR = "deployment_logs"
        BACKUP_DIR = "backups"
        PACKAGE_XML = "./manifest/package.xml"
        TEST_LEVEL = "RunLocalTests"
        WAIT_TIME = "30"
    }
    stages {

        stage('Prepare') {
            steps {
                script {
                    echo "[STEP] Creating log directory..."
                    if (!fileExists(env.LOG_DIR)) {
                        sh "mkdir -p ${env.LOG_DIR}"
                    }

                    echo "[STEP] Creating backup directory..."
                    BACKUP_FOLDER = "${env.BACKUP_DIR}/${new Date().format('yyyyMMdd_HHmm')}"
                    sh "mkdir -p ${BACKUP_FOLDER}"
                }
            }
        }

        stage('Backup XML') {
            steps {
                script {
                    echo "[STEP] Backing up XML file: ${params.XML_FILE}"
                    BACKUP_FILE = "${params.XML_FILE}.bak_${new Date().format('yyyyMMdd_HHmmss')}"
                    sh "cp ${params.XML_FILE} ${BACKUP_FILE}"
                    echo "Backup created at: ${BACKUP_FILE}"
                }
            }
        }

        stage('Update XML') {
            steps {
                script {
                    echo "[STEP] Updating XML..."
                    
                    // Parse tags map
                    def tags = [:]
                    params.TAGS_MAP.split("\n").each { line ->
                        if (line.trim()) {
                            def (key, value) = line.trim().split('=')
                            tags[key] = value
                        }
                    }

                    // Update XML using PowerShell
                    def psScript = """
                        [xml]\$xml = Get-Content "${params.XML_FILE}"
                        \$nsMgr = New-Object System.Xml.XmlNamespaceManager(\$xml.NameTable)
                        \$nsMgr.AddNamespace("ns", \$xml.DocumentElement.NamespaceURI)

                        ${tags.collect { key, value -> "\$xml.SelectSingleNode(\"//ns:${key}\", \$nsMgr).InnerText = '${value}'" }.join("\n")}

                        # Save updated XML
                        \$xml.Save("${params.XML_FILE}")
                    """
                    powershell(returnStatus: true, script: psScript)
                    echo "XML updated successfully"
                }
            }
        }

        stage('Validate Changes') {
            steps {
                script {
                    echo "[STEP] Validating XML..."
                    
                    def validationScript = """
                        [xml]\$xml = Get-Content "${params.XML_FILE}"
                        \$nsMgr = New-Object System.Xml.XmlNamespaceManager(\$xml.NameTable)
                        \$nsMgr.AddNamespace("ns", \$xml.DocumentElement.NamespaceURI)
                        \$valid = \$true
                        ${tags.collect { key, value -> "if (\$xml.SelectSingleNode(\"//ns:${key}\", \$nsMgr).InnerText -ne '${value}') { \$valid = \$false }" }.join("\n")}
                        if (-not \$valid) { exit 1 }
                    """
                    powershell(returnStatus: true, script: validationScript)
                    echo "Validation passed!"
                }
            }
        }

        stage('Deploy to Salesforce') {
            steps {
                script {
                    echo "[STEP] Deploying to org: ${params.ORG_ALIAS}"
                    sh """
                        chcp 65001
                        sf deploy metadata --manifest ${env.PACKAGE_XML} --target-org ${params.ORG_ALIAS} --test-level ${env.TEST_LEVEL} --wait ${env.WAIT_TIME} --json > ${env.LOG_DIR}/deploy_${new Date().format('yyyyMMdd_HHmmss')}.json
                    """
                }
            }
        }

        stage('Push Changes to GitHub') {
            steps {
                script {
                    echo "[STEP] Pushing updated XML to GitHub..."
                    sh """
                        git config user.email "jenkins@example.com"
                        git config user.name "Jenkins CI"
                        git add ${params.XML_FILE}
                        git commit -m "Updated ${params.XML_FILE} tags: ${tags.keySet().join(', ')}"
                        git push origin HEAD
                    """
                    echo "Changes pushed to GitHub."
                }
            }
        }
    }

    post {
        failure {
            echo "Pipeline failed. Restoring backup..."
            sh "cp ${BACKUP_FILE} ${params.XML_FILE}"
        }
    }
}
