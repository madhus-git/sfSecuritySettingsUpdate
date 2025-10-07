node {
    try {
        // ==================================================
        // 1️⃣ Parameters
        // ==================================================
        properties([
            parameters([
                string(name: 'ORG_ALIAS', defaultValue: 'dev', description: 'Salesforce Org alias'),
                text(name: 'UPDATE_MAP', defaultValue: 'canUsersGrantLoginAccess=false\nenableAdminLoginAsAnyUser=true', description: 'key=value pairs (one per line)')
            ])
        ])

        // ==================================================
        // 2️⃣ Checkout Source Code
        // ==================================================
        stage('Checkout') {
            echo "📦 Checking out source code..."
            checkout scm
        }

        // ==================================================
        // 3️⃣ Locate XML Files
        // ==================================================
        stage('Locate XML Files') {
            echo "🔍 Locating XML files under force-app/main/default/settings..."
            def xmlDir = new File("${env.WORKSPACE}/force-app/main/default/settings")
            if (!xmlDir.exists()) error "Settings directory not found: ${xmlDir}"

            def xmlFiles = []
            xmlDir.eachFileRecurse { file ->
                if (file.name.endsWith(".xml")) {
                    xmlFiles << file
                }
            }

            if (xmlFiles.isEmpty()) error "No XML files found in ${xmlDir}"
            env.XML_FILE_PATHS = xmlFiles.collect { it.path }.join(';')
            echo "Found ${xmlFiles.size()} XML file(s)."
        }

        // ==================================================
        // 4️⃣ Update XML Files
        // ==================================================
        stage('Update XML Files') {
            echo "🛠 Updating XML files..."

            def keysValues = [:]
            params.UPDATE_MAP.split("\n").each { line ->
                def parts = line.trim().split("=")
                if (parts.size() == 2) keysValues[parts[0].trim()] = parts[1].trim()
            }

            def xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }

            xmlFiles.each { file ->
                echo "Updating file: ${file.path}"
                def xml = new XmlParser().parse(file)

                keysValues.each { key, value ->
                    def node = xml."${key}"
                    if (node) {
                        node[0].value = value
                        echo "✅ Updated ${key} -> ${value}"
                    } else {
                        xml.appendNode(key, value)
                        echo "⚠️ Added missing node ${key} -> ${value}"
                    }
                }

                // Write XML back
                def writer = new FileWriter(file)
                def printer = new XmlNodePrinter(new PrintWriter(writer))
                printer.setPreserveWhitespace(true)
                printer.print(xml)
                writer.close()
            }
        }

        // ==================================================
        // 5️⃣ Validate Updates
        // ==================================================
        stage('Validate Updates') {
            echo "🔍 Validating XML updates..."
            def xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
            def failed = false

            xmlFiles.each { file ->
                def xml = new XmlParser().parse(file)
                params.UPDATE_MAP.split("\n").each { line ->
                    def (key, value) = line.trim().tokenize("=")
                    def nodeValue = xml."${key}" ? xml."${key}"[0].text() : null
                    if (nodeValue != value) {
                        echo "❌ Validation failed for ${key} in ${file.path}. Expected: ${value}, Found: ${nodeValue}"
                        failed = true
                    }
                }
            }

            if (failed) error "❌ XML validation failed!"
            echo "✅ All XML updates validated successfully."
        }

        // ==================================================
        // 6️⃣ Commit Updates to Git
        // ==================================================
        stage('Commit to Git') {
            echo "💾 Committing updates to Git..."
            def xmlFiles = env.XML_FILE_PATHS.split(';').collect { it.path }.join(' ')
            sh "git config user.email 'jenkins@local'"
            sh "git config user.name 'Jenkins'"
            sh "git add ${xmlFiles}"
            sh "git commit -m 'Automated XML update via Jenkins pipeline' || echo '⚠️ No changes to commit'"
            sh "git push origin HEAD:main || echo '⚠️ Push skipped'"
        }

        // ==================================================
        // 7️⃣ Deploy to Salesforce Org
        // ==================================================
        stage('Deploy to Salesforce Org') {
            echo "🚀 Deploying to Salesforce Org: ${params.ORG_ALIAS}"
            sh "sf project deploy start --source-dir force-app --target-org ${params.ORG_ALIAS} --ignore-warnings --verbose"
        }

        echo "🎉 Pipeline completed successfully for org: ${params.ORG_ALIAS}"

    } catch (err) {
        echo "❌ Pipeline failed: ${err.message}"
        currentBuild.result = 'FAILURE'
        throw err
    }
}
