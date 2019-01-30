pipeline {
  agent none

  stages {
    stage('Build') {

      agent { any }

      steps {
	sh "python setup.py build"
      }

    }

    stage('Test') {

      agent { any }

      steps {
	sh "true" // FIXME: should be "python setup.py test"
      }

      post {
	always {
	  script {
	    // set result before pipeline ends, so emailer sees it
	    currentBuild.result = currentBuild.currentResult
          }
          emailext(to:'seb@untangle.com', subject:"${env.JOB_NAME} #${env.BUILD_NUMBER}: ${currentBuild.result}", body:"${env.BUILD_URL}")
          slackSend(channel:"@Seb", message:"${env.JOB_NAME} #${env.BUILD_NUMBER}: ${currentBuild.result} at ${env.BUILD_URL}")
	}
	// changed {
	//   script {
	//     // set result before pipeline ends, so emailer sees it
	//     currentBuild.result = currentBuild.currentResult
        //   }
        //   emailext(to:'nfgw-engineering@untangle.com', subject:"${env.JOB_NAME} #${env.BUILD_NUMBER}: ${currentBuild.result}", body:"${env.BUILD_URL}")
        //   slackSend(channel:"#engineering", message:"${env.JOB_NAME} #${env.BUILD_NUMBER}: ${currentBuild.result} at ${env.BUILD_URL}")
	// }
      }
    }
  }
}
