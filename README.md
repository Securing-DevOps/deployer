# Securing DevOps's deployer
A simple API that receives webhook notifications, runs tests and trigger deployments.

Get your own copy
-----------------

To try out the code in this repository, first create a fork in your own github account.

Replace the namespace
~~~~~~~~~~~~~~~~~~~~~
Now before you do anything, edit the file `main.go` and replace `securingdevops` with your dockerhub username on line 50.
```go
if hookData.Repository.Namespace != `securingdevops` {
		httpError(w, http.StatusUnauthorized, "Invalid namespace")
		return
}
```
If your dockerhub username is `bobkelso`, then the code should read
```go
if hookData.Repository.Namespace != `bobkelso` {
		httpError(w, http.StatusUnauthorized, "Invalid namespace")
		return
}
```
When the deployer processes a webhook notification, it makes sure the notification comes from a trusted dockerhub user. You certainly don't want to leave that blank, otherwise anyone could send webhook notifications to your deployer and trigger new deployments.

Set your own environment
~~~~~~~~~~~~~~~~~~~~~~~~

Next, still in main.go, replace the following code with your own, taken from the invoicer's elastic beanstalk environment your created previously.

```go
	params := &elasticbeanstalk.UpdateEnvironmentInput{
		ApplicationName: aws.String("invoicer201707071231"),
		EnvironmentId:   aws.String("e-y8ubep55hp"),
		VersionLabel:    aws.String("invoicer-api"),
}
```
