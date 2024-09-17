---
title: What color is your auth? OAuth2 with Clojure and Temporal
date: 2024-09-15T20:00:00-05:00
---

Oauth2 has become the dominant authentication mechanism for Web APIs. It is more secure than than
API keys since the user invovled in the login flow (more on this later), and since the tokens it
produced are short-lived.

Major tech giants like Google and Amazon rely on OAuth2 to gatekeep access to hundreds of APIs. The
trend is likely to continue.

OAuth2 is simple in principle, but a bit tricky to implement. This is because its main
authentication flow, called the authorization code grant flow, is callback-driven. This can result
in a lot of logic in the handlers, and makes separation of concerns more tricky.

(Most Web application [architectures][hexagonal] would recommend strict separation between handler
code and domain logic to result in more portable and testable code. This becomes harder when
handlers are also part of your domain logic - which OAuth2 kind of forces on you.)

[hexagonal]: https://en.wikipedia.org/wiki/Hexagonal_architecture_(software)

I have been checking out [HappyAPI][happyapi], by Timothy Pratley. It is a newly released Clojure
library which simplifies authenticaton with OAuth2 APIs, without relying on Java SDKs for each
provider. The library uses code generation to turn API specifications into runnable specifications
as Clojure data structures. In this way, it is aligned with the trend towards data-driven libraries,
like Muuntaja, Reitit, etc.

HappyAPI handles an OAuth2 authentication flow, described in more detail below, entirely through
middleware. When the library user make a request, it will authenticate (or refresh an existing
authentication) in its middleware chain.

It handles the asynchronous authorization code grant by starting up an internal Web server, waiting
for an authorization code from the provider, and then shutting it down.

I was surprised the first time I tried it and found it "just worked", having implemented similar flows
before with some amount of trial and error. I think part of the reason it works surprisingly well is
that its middleware stack is guaranteed to either return an authentication token or an error. It
will block on the code exchange until it gets called back.

[happyapi]: https://github.com/timothypratley/happyapi

I tried using this library in a Web application, and found that it was hard to keep the appealing
simplicity of the original. Some of the logic in synchronous, some async, resulted in messiness.

It's the "what color is your code?" thing, but for auth. Timothy's comment alludes to the compromise
in favor of simplicity:

"Only the http request is asynchronous; reading, updating, or writing credentials is
done synchronously. Asynchronously obtaining credentials is challenging because it may rely on
waiting for a redirect back. This compromise allows for convenient usage, but means that calls may
block while authorizing before the http request is made."

We will try an approach with Temporal that _feels synchronous_. In the large, Temporal is a
workflow orchestration tool that can orchestrate complex work in microservice architecture. In the
small, it lets you write code that looks synchronous, and behaves as though it is asynchronous. You
can start execution, pause them for a time, and then finish. 

This should be perfect writing a simple authentication chain. Let's find out.

## OAuth2 flow

The steps in the Oauth2 [authorization code grant][auth-code] involves a resource owner, an
authorization server, and an application, as shown in the image below.

[auth-seq](images/authcode.webp)

[auth-code]: https://datatracker.ietf.org/doc/html/rfc6749#section-1.3.1

When a user tries to access a protected resource, they are rediceted to a login apge. This login
link contains a "state" parameter, lated validated by the client when the user is redirected back
with an authorization code. This state parameter is also useful for tying a request back to a
particular user or session.

If the state parameter is OK, the client exchanges the auth code for an access token and refresh
token. Access tokens are valid for a short time period - for Google, it's an hour - and can be
refreshed by changing the `grant_type` and passing the refresh token. Refresh tokens validity is
typically undocumented, but they seem to last months or even years.

Web application store access tokens and refresh tokens in the database in an encrypted format, like
a password. On every request to a protected resource, the client checks if the access token is still
valid, and refreshes it otherise.

## Implementation

While these steps are straightforward, implementing this workflow can still be a bit frustrating.
The problem lies in the fact that steps 1 through 4 don’t fit neatly into a single function.

This can make the code harder to follow, as the logic is scattered across different parts of the
codebase. It can also make it harder to work into middlware. (Although the ring spec does provide
an async arity which may be enough; this is explored more int he conclusions.)

It would be ideal to create a single function that handles the entire authentication state—from
generating the state string to exchanging tokens and storing them in a database. This would not only
improve readability but also reduce the likelihood of errors, making the authentication flow more
robust and easier to manage.

Along with application models, this kind of DB-based process will make you create DB models, such as
`auth-state` or `auth-request`, which are not part of your application's functionality. These are
short-lived and amount to nose.

The basic pattern I have been exploring recently is based on [yum brands video]: use the database
for models that are significant to the applicaiton, keep the "in-progress" state in Temporal.

The same IDs can be used for the workflows and models, which makes it easy to track.

Before looking at the code, let's do a quick overview of Temporal.

## Temporal

Temporal is a workflow orchestration tool to run long-running workflows. It provides a friendly user
interface and developer-friendly SDKs for many languages.

This application allows the user to connect efficiently to a Google Sheet.

## Setup

The code is here

[code]: https://github.com/kpassapk/happyapi-temporal

Create a [client][setup], set the redirect URL to http://localhost:8080/redirect, retain client ID
and secret, and add to .env file as

[setup]: https://console.cloud.google.com/apis/credentials

## Deps

In [deps.edn][deps], we use HappyAPI v0.1.3 and the `unifica/temporal` library, which uses the
Manetu [Clojure SDK][manetu] and adds some convenience functions that make it easier to use with
Biff. The remaining dependencies are out off hte obx 

[manetu]: https://github.com/manetu/temporal-clojure-sdk

[deps]: https://github.com/kpassapk/happyapi-temporal/blob/main/deps.edn

## Configuration and schema

In `resources/config.edn`, we configure the HTTP client and JSON library to the ones used by Biff. 

```clojure
{
   ...
   :happyapi/config
	{:google {:deps            [:clj-http :cheshire]
			  :client_id       #biff/env HAPPYAPI_GOOGLE_CLIENT_ID
			  :client_secret   #biff/env HAPPYAPI_GOOGLE_SECRET
			  :redirect_uri    "http://localhost:8080/redirect"
			  :scopes          []
			  :keywordize-keys true}}
   ...
}
```

We load this configuration on application startup.

Our application will create an `auth` with an access token. Here is the `malli` schema:

```
{
  :auth/id :uuid
	 :auth [:map {:closed true}
			[:xt/id              :auth/id]
			[:auth/request       :auth-request/id]
			[:auth/provider      :keyword]
			[:auth/user          :user/id]
			[:auth/access_token  :string]
			[:auth/refresh_token :string]
			[:auth/scope         :string]
			[:auth/token_type    :string]
			[:auth/created_at    inst?]
			[:auth/expires_at    inst?]]
}
```

## Handlers

A welcome page for users of an app, displaying different options depending on the user’s authentication status.

```
(defn home-page [{:keys [biff/db app/get-user] :as ctx}]
  (let [user (get-user ctx)
        auth (biff/lookup db :auth/user user)]
    (ui/page
     ctx
     [:h1 "Welcome to your app!"]
     [:.h-4]
     [:.flex
      (if auth
        [:a.link {:href "/spreadsheet"} "Show spreadsheet"]
        [:a.link {:href "/start"} "Start authentication"])])))
```

The `start-auth` function is initiates an authentication process. It uses the [spreadsheets-get][spreadsheets-get]
function from the happyapi-google library, which returns request data that can later be provided to
a wrapped HTTP client. This request data is 

We are requesting the scopes necessary to get a single spreadsheet.

[spreadsheets-get]: https://github.com/timothypratley/happyapi.google/blob/main/src/happyapi/google/sheets_v4.clj

```
(defn start-auth [{:keys [biff/db] :as ctx}]
  (let [args (sheets/spreadsheets-get nil) ;; hacky
        scopes (:scopes args)
        user (biff/lookup-id db :user/email "kyle@unifica.ai")
        auth (auth/start ctx {:user user
                              :provider :google
                              :scopes scopes})
        login-url (:login-url auth)]
    (ui/page
     ctx
     [:h1 "Start authentication"]
     [:.flex
      [:a.btn {:href login-url} "Log in with Google"]])))
```

The finish-auth handler gets code and state strings from query params and passes them on to the `auth/finish` function.

```
(defn finish-auth [{:keys [query-params] :as ctx}]
  (let [{:strs [code state]} query-params
        result (auth/finish ctx {:code code :state state})])
  {:status 303
   :headers {"location" "/"}})
```

## Workflows 


## Conclusions

This fragmentation isn’t unique to OAuth2 workflows. Many developers and platforms have struggled
with the need for a more compact way to describe asynchronous processes. This is evident in the rise
of low-code tools like Make and n8n, designed to simplify workflows by consolidating such processes.

Included a ring async handler arity in the middleware. This may be enough to work this async-nes
into the code.

We will try an approach that feels very synchronous. In the large, Temporal is a workflow
