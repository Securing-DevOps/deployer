// Copied from go.mozilla.org/cloudops-deployment-proxy
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"
)

var DockerhubRegistry = "https://registry.hub.docker.com"

// CallBackData is the data format described at https://docs.docker.com/docker-hub/webhooks/#callback-json-data
type CallBackData struct {
	State       string `json:"state,omitempty"`
	Description string `json:"description,omitempty"`
	Context     string `json:"context,omitempty"`
	TargetURL   string `json:"target_url,omitempty"`
}

// Returns a success callback with state: success
func NewSuccessCallbackData() *CallBackData {
	return &CallBackData{
		State: "success",
	}
}

// DockerHubWebhookData represents the dockerhub webhook format
type DockerHubWebhookData struct {
	PushData struct {
		PushedAt int      `json:"pushed_at"`
		Images   []string `json:"images"`
		Tag      string   `json:"tag"`
		Pusher   string   `json:"pusher"`
	} `json:"push_data"`
	CallbackURL string `json:"callback_url"`
	Repository  struct {
		Status          string `json:"status"`
		Description     string `json:"description"`
		IsTrusted       bool   `json:"is_trusted"`
		FullDescription string `json:"full_description"`
		RepoURL         string `json:"repo_url"`
		Owner           string `json:"owner"`
		IsOfficial      bool   `json:"is_official"`
		IsPrivate       bool   `json:"is_private"`
		Name            string `json:"name"`
		Namespace       string `json:"namespace"`
		StarCount       int    `json:"star_count"`
		CommentCount    int    `json:"comment_count"`
		DateCreated     int    `json:"date_created"`
		RepoName        string `json:"repo_name"`
	} `json:"repository"`
}

// Callback calls data's callback_url
func (d *DockerHubWebhookData) Callback(cb *CallBackData) error {
	callbackPrefix := fmt.Sprintf("%s/u/%s/%s/hook/",
		DockerhubRegistry, d.Repository.Namespace, d.Repository.Name)
	if !strings.HasPrefix(d.CallbackURL, callbackPrefix) {
		return fmt.Errorf("d.CallBackURL does not start with %s", callbackPrefix)
	}
	data, err := json.Marshal(cb)
	if err != nil {
		return err
	}
	resp, err := http.Post(d.CallbackURL, "application/json", bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("Error calling callback_url: %v", err)
	}
	if resp.StatusCode != 200 {
		return errors.New("callback_url did not return 200")
	}
	return nil
}

// NewDockerHubWebhookData returns *DockerHubWebhookData from json bytes
func NewDockerHubWebhookData(b []byte) (*DockerHubWebhookData, error) {
	data := new(DockerHubWebhookData)
	err := json.Unmarshal(b, data)
	return data, err
}

// NewDockerHubWebhookDataFromRequest returns *DockerHubWebhookData from http.Request
// Body is returned intact unless error != nil
func NewDockerHubWebhookDataFromRequest(req *http.Request) (*DockerHubWebhookData, error) {
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		return nil, fmt.Errorf("Error reading request body: %v", err)
	}

	req.Body = ioutil.NopCloser(bytes.NewReader(body))

	hookData, err := NewDockerHubWebhookData(body)
	if err != nil {
		return nil, fmt.Errorf("Error unmarshaling json: %v", err)
	}
	return hookData, nil
}
