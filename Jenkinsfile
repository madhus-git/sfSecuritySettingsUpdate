node {
    // -------------------------------
    // 0️⃣ Parameters
    // -------------------------------
    def orgAlias = params.ORG_ALIAS ?: input(message: 'Enter Salesforce Org Alias', parameters: [string(name: 'ORG_ALIAS')])
    def xmlFilesInput = params.XML_FILES ?: input(message: 'Enter XML files (comma-separated)', parameters: [string(name: 'XML_FILES')])
    def tagsInput = params.TAGS_MAP ?: input(message: 'Enter tags for each XML (format: filePath:tag1=value1,tag2=value2)', parameters: [text(name: 'TAGS_MAP')])

    def logDir = "deployment_logs"
    def backupDir = "backups"
    def packageXml = "./manifest/package.xml"
    def waitTime = 30
    def testLevel = "RunLocalTests"
    def timestamp = new Date().format('yyyyMMdd_HHmmss')
    def backupFiles = [:] // Map to track backups for rollback

    // -------------------------------
    // Helper Function: Parse tags
    // -------------------------------
    def parseTags = { tagsStr ->
        def map = [:]
        tagsStr.split(",").each { kv ->
            def pair = kv.trim().split("=")
            if(pair.size() == 2) { map[pair[0]] = pair[1] }
        }
        return map
    }

    // -------------------------------
    // 1️⃣ Prepare directories
    // -------------------------------
    stage('Prepare') {
        echo "[STEP] Creating log and backup directories..."
        sh "mkdir -p ${logDir} ${backupDir}"
    }

    // -------------------------------
    // 2️⃣ Backup XML files
    // -------------------------------
    stage('Backup XML') {
        echo "[STEP] Backing up XML files..."
        xmlFilesInput.split(",").each { file ->
            file = file.trim()
            def backupFile = "${file}.bak_${timestamp}"
            backupFiles[file] = backupFile
            sh "cp ${file} ${backupFile}"
            echo "Backup created: ${backupFile}"
        }
    }

    // -------------------------------
    // 3️⃣ Update XML files
    // -------------------------------
    stage('Update XML') {
        echo "[STEP] Updating XML files..."
        tagsInput.split("\n").each { line ->
            if(line.trim()) {
                def parts = line.split(":")
                if(parts.size() != 2) { error "Invalid format in TAGS_MAP: ${line}" }
                def xmlFile = parts[0].trim()
                def tags = parseTags(parts[1].trim())

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

    // -------------------------------
    // 4️⃣ Validate updated XML values
    // -------------------------------
    stage('Validate Changes') {
        echo "[STEP] Validating XML updates..."
        tagsInput.split("\n").each { line ->
            if(line.trim()) {
                def parts = line.split(":")
                def xmlFile = parts[0].trim()
                def tags = parseTags(parts[1].trim())

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

    // -------------------------------
    // 5️⃣ Deploy to Salesforce
    // -------------------------------
    stage('Deploy to Salesforce') {
        echo "[STEP] Deploying to org: ${orgAlias}"
        def deployLog = "${logDir}/deploy_${timestamp}.json"
        sh """
            chcp 65001
            sf deploy metadata --manifest ${packageXml} --target-org ${orgAlias} --test-level ${testLevel} --wait ${waitTime} --json > ${deployLog}
        """
        echo "Deployment completed. Log: ${deployLog}"
    }

    // -------------------------------
    // 6️⃣ Push updated XML files to GitHub
    // -------------------------------
    stage('Push to GitHub') {
        echo "[STEP] Pushing updated XML files to GitHub..."
        sh """
            git config user.email "jenkins@example.com"
            git config user.name "Jenkins CI"
            ${xmlFilesInput.split(",").collect { f -> "git add ${f.trim()}" }.join("\n")}
            git commit -m "Updated XML files: ${xmlFilesInput.replaceAll(',', ', ')}"
            git push origin HEAD
        """
        echo "Changes pushed to GitHub successfully."
    }

    // -------------------------------
    // Post-failure rollback
    // -------------------------------
    catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
        stage('Rollback on Failure') {
            if(backupFiles.size() > 0) {
                echo "[ROLLBACK] Restoring backups..."
                backupFiles.each { orig, backup ->
                    if(fileExists(backup)) {
                        sh "cp ${backup} ${orig}"
                        echo "Restored ${orig} from ${backup}"
                    }
                }
            }
        }
    }
}
