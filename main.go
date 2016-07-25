// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Contributor: Julien Vehent jvehent@mozilla.com [:ulfr]
package main

//go:generate ./version.sh

import (
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"path/filepath"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/elasticbeanstalk"
	"github.com/gorilla/mux"
)

type deployer struct {
}

func main() {
	var dplr deployer

	// register routes
	r := mux.NewRouter()
	r.HandleFunc("/dockerhub", dplr.postWebHook).Methods("POST")
	r.HandleFunc("/__heartbeat__", getHeartbeat).Methods("GET")
	r.HandleFunc("/__version__", getVersion).Methods("GET")

	// all set, start the http handler
	log.Fatal(http.ListenAndServe(":8080", r))
}

func (dplr *deployer) postWebHook(w http.ResponseWriter, r *http.Request) {
	log.Println("Received webhook")
	hookData, err := NewDockerHubWebhookDataFromRequest(r)
	if err != nil {
		httpError(w, http.StatusInternalServerError, "Failed to initialize DockerHub Webhook parser")
		return
	}
	log.Printf("%+v", hookData)
	// This application only accepts containers placed under the
	// `securingdevops` dockerhub organization. If this wasn't an
	// example application, we would make the namespacing configurable
	if hookData.Repository.Namespace != `securingdevops` {
		httpError(w, http.StatusUnauthorized, "Invalid namespace")
		return
	}
	err = hookData.Callback(NewSuccessCallbackData())
	if err != nil {
		httpError(w, http.StatusUnauthorized, "Request could not be validated")
		return
	}

	go testAndDeploy()
	w.Write([]byte("OK"))
}

func testAndDeploy() {
	testFiles, err := filepath.Glob("/app/deploymentTests/*")
	if err != nil {
		panic(err)
	}
	var do_deploy = true
	for _, testFile := range testFiles {
		log.Println("Executing test", testFile)
		out, err := exec.Command(testFile).Output()
		if err != nil {
			log.Printf("Test %s failed:\n%s\n%s", testFile, err, out)
			do_deploy = false
		}
		log.Printf("Test %s succeeded: %s", testFile, out)
	}
	if do_deploy {
		deploy()
	}
}

func deploy() {
	svc := elasticbeanstalk.New(
		session.New(),
		&aws.Config{Region: aws.String("us-east-1")},
	)

	params := &elasticbeanstalk.UpdateEnvironmentInput{
		ApplicationName: aws.String("invoicer201605211320"),
		EnvironmentId:   aws.String("e-curu6awket"),
		VersionLabel:    aws.String("invoicer-api"),
	}
	resp, err := svc.UpdateEnvironment(params)

	if err != nil {
		// Print the error, cast err to awserr.Error to get the Code and
		// Message from an error.
		log.Println(err)
		return
	}

	// Pretty-print the response data.
	log.Println("Deploying EBS application:", params)
	log.Println(resp)
}

func getHeartbeat(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("I am alive"))
}

// handleVersion returns the current version of the API
func getVersion(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(fmt.Sprintf(`{
"source": "https://github.com/Securing-DevOps/deployer",
"version": "%s",
"commit": "%s",
"build": "https://circleci.com/gh/Securing-DevOps/deployer/"
}`, version, commit)))
}

func httpError(w http.ResponseWriter, errorCode int, errorMessage string, args ...interface{}) {
	log.Printf("%d: %s", errorCode, fmt.Sprintf(errorMessage, args...))
	http.Error(w, fmt.Sprintf(errorMessage, args...), errorCode)
	return
}
