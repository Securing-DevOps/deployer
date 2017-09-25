# Securing DevOps's deployer
A simple API that receives webhook notifications, runs tests and trigger deployments.

Get your own copy
-----------------

To try out the code in this repository, first create a fork in your own github account.

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
