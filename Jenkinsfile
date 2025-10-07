pipeline {
    agent any
    parameters {
        string(name: 'ORG_ALIAS', defaultValue: 'devOrg', description: 'Salesforce org alias for deployment')
        string(name: 'XML_FILES', defaultValue: 'force-app/main/default/settings/Security.settings-meta.xml', description: 'Comma-separated XML files to update')
        text(name: 'TAGS_MAP', defaultValue: 'force-app/main/default/settings/Security.settings-meta.xml:canUsersGrantLoginAccess=false,enableAdminLoginAsAnyUser=true', description: 'Format: filePath:tag1=value1,tag2=value2 per line')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    echo "[STEP] Creating log and backup directories..."
                    def logDir = "deployment_logs"
                    def backupDir = "backups"
                    if (isUnix()) {
                        sh "mkdir -p ${logDir} ${backupDir}"
                    } else {
                        bat """
                            if not exist "${logDir}" mkdir "${logDir}"
                            if not exist "${backupDir}" mkdir "${backupDir}"
                        """
                    }
                }
            }
        }

        stage('Backup XML') {
            steps {
                script {
                    def timestamp = new Date().format('yyyyMMdd_HHmmss')
                    def backupFiles = [:]
                    XML_FILES.split(",").each { file ->
                        file = file.trim()
                        def backupFile = "${file}.bak_${timestamp}"
                        backupFiles[file] = backupFile
                        // Validate file exists
                        if (isUnix()) {
                            sh "test -f ${file} || (echo File not found: ${file} && exit 1)"
                            sh "cp ${file} ${backupFile}"
                        } else {
                            bat "if not exist \"${file}\" (echo File not found: ${file} & exit 1)"
                            bat "copy /Y \"${file}\" \"${backupFile}\""
                        }
                        echo "Backup created: ${backupFile}"
                    }
                    // Store backup map in env variable for rollback
                    env.BACKUP_FILES = groovy.json.JsonOutput.toJson(backupFiles)
                }
            }
        }

        stage('Update XML') {
            steps {
                script {
                    TAGS_MAP.split("\n").each { line ->
                        if(line.trim()) {
                            def parts = line.split(":")
                            if(parts.size() != 2) { error "Invalid format in TAGS_MAP: ${line}" }
                            def xmlFile = parts[0].trim()
                            def tags = parts[1].trim().split(",").collectEntries { kv ->
                                def pair = kv.split("=")
                                [(pair[0].trim()) : pair[1].trim()]
                            }

                            echo "Updating ${xmlFile} with tags: ${tags}"

                            def psScript = """
                                [xml]\$xml = Get-Content "${xmlFile}"
                                \$nsMgr = New-Object System.Xml.XmlNamespaceManager(\$xml.NameTable)
                                \$nsMgr.AddNamespace("ns", \$xml.DocumentElement.NamespaceURI)
                                ${tags.collect { k,v -> "\$xml.SelectSingleNode(\"//ns:${k}\", \$nsMgr).InnerText = '${v}'" }.join("\n")}
                                \$xml.Save("${xmlFile}")
                            """

                            powershell(returnStatus: true, script: psScript)
                        }
                    }
                    echo "XML files updated successfully."
                }
            }
        }

        stage('Validate Changes') {
            steps {
                script {
                    TAGS_MAP.split("\n").each { line ->
                        if(line.trim()) {
                            def parts = line.split(":")
                            def xmlFile = parts[0].trim()
                            def tags = parts[1].trim().split(",").collectEntries { kv ->
                                def pair = kv.split("=")
                                [(pair[0].trim()) : pair[1].trim()]
                            }

                            def validationScript = """
                                [xml]\$xml = Get-Content "${xmlFile}"
                                \$nsMgr = New-Object System.Xml.XmlNamespaceManager(\$xml.NameTable)
                                \$nsMgr.AddNamespace("ns", \$xml.DocumentElement.NamespaceURI)
                                \$valid = \$true
                                ${tags.collect { k,v -> "if (\$xml.SelectSingleNode(\"//ns:${k}\", \$nsMgr).InnerText -ne '${v}') { \$valid = \$false }" }.join("\n")}
                                if (-not \$valid) { exit 1 }
                            """

                            powershell(returnStatus: true, script: validationScript)
                        }
                    }
                    echo "Validation passed for all XML files."
                }
            }
        }

        stage('Deploy to Salesforce') {
            steps {
                script {
                    def deployLog = "deployment_logs/deploy_${new Date().format('yyyyMMdd_HHmmss')}.json"
                    if (isUnix()) {
                        sh "sf deploy metadata --manifest ./manifest/package.xml --target-org ${ORG_ALIAS} --test-level RunLocalTests --wait 30 --json > ${deployLog}"
                    } else {
                        bat "sf deploy metadata --manifest ./manifest/package.xml --target-org ${ORG_ALIAS} --test-level RunLocalTests --wait 30 --json > ${deployLog}"
                    }
                    echo "Deployment completed. Log: ${deployLog}"
                }
            }
        }

        stage('Push to GitHub') {
            steps {
                script {
                    if (isUnix()) {
                        sh "git config user.email 'jenkins@example.com' && git config user.name 'Jenkins CI'"
                    } else {
                        bat "git config user.email 'jenkins@example.com' & git config user.name 'Jenkins CI'"
                    }

                    XML_FILES.split(",").each { file ->
                        file = file.trim()
                        if (isUnix()) { sh "git add ${file}" } else { bat "git add \"${file}\"" }
                    }

                    if (isUnix()) {
                        sh "git commit -m 'Updated XML files' || echo 'No changes to commit'"
                        sh "git push origin HEAD"
                    } else {
                        bat "git commit -m \"Updated XML files\" || echo No changes to commit"
                        bat "git push origin HEAD"
                    }

                    echo "Changes pushed to GitHub successfully."
                }
            }
        }
    }

    post {
        failure {
            script {
                echo "[ROLLBACK] Restoring backups..."
                def backupFiles = groovy.json.JsonSlurperClassic().parseText(env.BACKUP_FILES)
                backupFiles.each { orig, backup ->
                    if (isUnix()) {
                        sh "cp ${backup} ${orig}"
                    } else {
                        bat "copy /Y \"${backup}\" \"${orig}\""
                    }
                    echo "Restored ${orig} from ${backup}"
                }
            }
        }
    }
}
