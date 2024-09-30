---
title: What color is your auth? OAuth2 with Clojure and Temporal
date: 2024-09-15T20:00:00-05:00
draft: false
---

Oauth2 has become the dominant authentication mechanism for Web APIs. It is more secure than than
API keys since the user is invovled in the login flow - more on this later - and since the tokens it
produced are short-lived.

Tech giants like Google and Amazon rely on OAuth2 to gatekeep access to their immense fleet of APIs.
The trend is likely to continue as second authentication factors, passkeys or biometrics become more
improtant.

OAuth2 is simple in principle, but a bit tricky to implement. This is because its main
authentication flow, called the authorization code flow, is callback-driven. This makes it
hard to write scripts or applications that run in the background; in web apps which do have HTTP
handlers that can handle callbacks, it can result in poor separation of concerns and brittle code.

Over the last few weeks, I have been checking out [HappyAPI][happyapi], by Timothy Pratley. This
newly released Clojure library simplifies authenticaton with OAuth2 APIs, without relying on Java
SDKs for each provider. The library uses code generation to turn API specifications into runnable
specifications. In this way, it is aligned with the trend towards data-driven libraries, like
Muuntaja, Reitit, etc.

[happyapi]: https://github.com/timothypratley/happyapi

HappyAPI handles an OAuth2 authentication flow, described in more detail below, entirely through
middleware. When the library user make a request, it will authenticate (or refresh an existing
authentication) in its middleware chain.

It handles the asynchronous authorization code grant by starting up an internal Web server, waiting
for an authorization code from the provider, and then shutting it down.

I was surprised the first time I tried it and found it "just worked", having implemented similar flows
before with some amount of trial and error. I think part of the reason it works surprisingly well is
that its middleware stack is guaranteed to either return an authentication token or an error. It
will block on the code exchange until it gets called back.

When I tried using this library in a Web application, though, I found that it was hard to keep the
appealing simplicity of the original. Some of the logic in synchronous, some async, resulted in
messiness. It's the "what color is your code?" thing, but for auth. 

Timothy's comment alludes to the compromise in favor of simplicity:

"Only the http request is asynchronous; reading, updating, or writing credentials is
done synchronously. Asynchronously obtaining credentials is challenging because it may rely on
waiting for a redirect back. This compromise allows for convenient usage, but means that calls may
block while authorizing before the http request is made."

In this post, we will implement an alternative with [Temporal][temporal] that behaves synchronously,
but is asynchronous under the hood. In the large, Temporal is a workflow orchestration tool for
orchestrating work in complex microservice architectures. In the small, it lets you write code that
looks synchronous, and behaves as though it is asynchronous. 

It is similar to core async or project loom, but works without a ton of macros and with several
client languages. It also allows us to pick up work from where we left off, even if another machine
 started the work. Lastly, it  has a nice UI to provide observability.

[temporal]: https://temporal.io

Although this is example is simple, it shows how we can implement applications that have resources
with long-running setup, potentially involving other systems or people in the loop, all without
talking about UI concerns. 

[yum brands] talks about this kind of thing.

## OAuth2 flow

The steps in the Oauth2 [authorization code grant][auth-code] involves a resource owner, an
authorization server, and an application, as shown in the image below.

![auth-seq](authcode.webp)

[auth-code]: https://datatracker.ietf.org/doc/html/rfc6749#section-1.3.1

When a user tries to access a protected resource, they are rediceted to a login apge. This login
link contains a "state" parameter, lated validated by the client when the user is redirected back
with an authorization code. 

If the state parameter is OK, the client exchanges the auth code for an access token and refresh
token. Access tokens are valid for a short time period - for Google, it's an hour - and can be
refreshed by changing the `grant_type` and passing the refresh token. Refresh tokens validity is
typically undocumented, but they seem to last many months or even years.

Web application store access tokens and refresh tokens in the database in an encrypted format, like
a password. On every request to a protected resource, the client checks if the access token is still
valid, and refreshes it otherise.

## Objective

we want to create an application that allows the user to log in to Google with enough access scope
to show the contents of a Google Sheet on screen. 

![Basic flow](basic-flow.png)

If the user is unauthenticated, they should see a "Sign in with Google" button. Once redirected
back, they should see a login link. When they click on this link, they should see the contents of
the sheet. For purposes of this post, we will print the sheet as a JSON document on screen.

We want to implement this application as simply as possible. The authorization workflow should be a
single function, which returns an access token.

In keeping with the simplicity idea, we would like to avoid creating database schemas for
short-lived state management - in other words, avoid having models like `auth-state` or
`auth-request`, which are not part of the application's functionality. 

The basic pattern I have been exploring recently is based on [yum brands video]: use the database
for models that are significant to the applicaiton, keep the "in-progress" state in Temporal.

Oh and we want the app process to be obserable.

## Setup

The [code][code] is here.

[code]: https://github.com/kpassapk/happyapi-temporal

Create a [client][setup], set the redirect URL to http://localhost:8080/redirect, retain client ID
and secret, and add to .env file.

[setup]: https://console.cloud.google.com/apis/credentials

In [deps.edn][deps], we use HappyAPI v0.1.3 and the [unifica/temporal][unifica-temporal] library, which uses the
Manetu [Clojure SDK][manetu] and adds some convenience functions that make it easier to use with
Biff. The remaining dependencies are out of the box.

[unifica-temporal]: https://github.com/unifica-ai/components/tree/main/temporal

[manetu]: https://github.com/manetu/temporal-clojure-sdk

[deps]: https://github.com/kpassapk/happyapi-temporal/blob/main/deps.edn

In `resources/config.edn`, we configure the HTTP client and JSON library to the ones used by Biff.
([Clj-HTTP][clj-http] / [Cheshire][cheshire]). This configurability is one of the innovative things
about HappyAPI.

[clj-http]: https://github.com/dakrone/clj-http
[cheshire]: https://github.com/dakrone/cheshire

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

We load and validate this configuration on application startup using HappyAPI's `prepare-config` function.

```clojure
(defn use-happyapi-config
  "Expand happyapi configuration"
  [{:keys [happyapi/config] :as ctx}]
  (let [config (->> (for [[provider] config]
                      [provider (happyapi/prepare-config provider config)])
                    (into {}))]
    (assoc ctx :happyapi/config config)))
```

The spreadsheet ID is in an environment variable called `GSHEETS_SHEET_ID`.

```clojure
 :gsheets/spreadsheet-id #biff/env "GSHEETS_SHEET_ID"
```

Our application will create an `auth` with an access token. Here is the malli schema:

```clojure
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

The home page displays a link to a spreadsheet if we are authenticated, and allows us to start an
authentication otherwise.

```clojure
(defn home-page [{:keys [biff/db app/get-user] :as ctx}]
  (let [user (get-user ctx)
        auth (biff/lookup db :auth/user user)]
    (ui/page
     ctx
     [:h1 "HappyAPI + Temporal"]
     [:.h-4]
     [:.flex
      (if auth
        [:a.link {:href "/spreadsheet"} "Show spreadsheet"]
        [:a.link {:href "/start"} "Start authentication"])])))
```

The `start-auth` function is initiates an authentication process. It uses the [spreadsheets-get][spreadsheets-get]
function from the happyapi-google library, which returns request data that can later be provided to
a wrapped HTTP client. 

We are requesting the scopes necessary to get a single spreadsheet.

[spreadsheets-get]: https://github.com/timothypratley/happyapi.google/blob/main/src/happyapi/google/sheets_v4.clj

"Log in with Google" contain the OAuth2 state parameter and are only valid for a few minutes. 

We call `auth/start` to obtain a login link given a user ID, provider and scope list, getting back a
login URL. This URL should in theory be valid only for a minutes.

```clojure
(defn start-auth [{:keys [biff/db] :as ctx}]
  (let [args   (sheets/spreadsheets-get nil) ;; hacky
        scopes (:scopes args)
        user   (biff/lookup-id db :user/email "kyle@unifica.ai")
        auth   (auth/start ctx {:user user
                                :provider :google
                                :scopes scopes})
        login-url (:login-url auth)]
    (ui/page
     ctx
     [:h1 "Start authentication"]
     [:.flex
      [:a.btn {:href login-url} "Log in with Google"]])))
```

We could also have had the link pointing to an application endpoint, and redirect to Google once the
user clicks. I would probably do this in a larger application to capture the user click event, but
in this example we will render a link straight to Google and consider the auth started even if the
user hasn't yet clicked on it.

The `finish-auth` handler gets code and state strings from query params and passes them on to the
`auth/finish` function.

```clojure
(defn finish-auth [{:keys [query-params] :as ctx}]
  (let [{:strs [code state]} query-params
        result (auth/finish ctx {:code code :state state})])
  {:status 303
   :headers {"location" "/"}})
```

Next we will look at the implementation of `auth/start` and `auth/finish`, which both tie into a
single Temporal authentication workflow.

## Authentication workflow

The `auth/start` function checks parameters passed in by the user and starts the authentication
workflow.

```clojure
(defn start [ctx {:keys [user provider scopes] :as params}]
  (if (u/valid? ctx ::create params)
    (let [id (str (random-uuid))
          params (assoc params :state id)]
      (do
        (workflow/start ctx authentication {:id id :params params})
        {:login-url (get-link ctx params)}))
    (throw+ 
     {:type ::invalid-params
      :cause (u/explain ctx ::create params)})))
```

The `auth/finish` function is similar, but sends a `::callback` signal, passing the auth code and
state. (A signal is a named message with arguments, which the workflow can recognize and react to.)

```clojure
(defn finish [ctx {:keys [code state] :as params}]
  (if (u/valid? ctx ::finish params)
    @(-> (workflow/start ctx authentication
                           {:id state
                            :signal ::callback
                            :signal-params params})
         tc/get-result)
    (throw+ {:type ::invalid-params
             :explain (u/explain ctx ::finish params)})))
```

By looking at the last two functions, you can se that `workflow/start` is the single entrypoint to
either starting a workflow or continuing a workflow that is already running. This is one of the key
design decisions of Temporal, and it takes some time to get used to. It is also what makes it
powerful: a long-running workflow (function) can be started by one process and then picked up by
another, perhaps on a different machine.

The rule is that a worflow with a given ID is only runs once at a time. If that workflow is
stopped - in our example, it stops while waiting for an auth code - it can be restarted by [sending
a signal to it][signal-with-start].

[signal-with-start]: https://www.restack.io/docs/temporal-knowledge-temporal-io-wait-for-signal-guide

In our example, we create a random UUID to start the workflow, and then get the same ID back from
Google as the state parameter. We will see this later in the UI later.

The authentication workflow itself is implemented using the `defworkflow` macro. It defines a
function and registers it with the Temporal cluster, in one go. The workflow declares an internal
state atom, defines a signal handler, and then waits until the state atom contains an access token.
This waiting step parks the workflow, and it is possible to have thousands of parked workflows
concurrently.

```clojure
(defworkflow authentication [{:keys [state] :as wf-args}]
  ;; Use workflow arguments as initial workflow state
  (let [wf-state (atom wf-args)]

    ;; Exchange code on callback signal
    (sig/register-signal-handler!
     (fn [signal-name {:keys [state] :as args}]
       (when (= (keyword signal-name) ::callback)
         (let [expected (:state @wf-state)
               result   (if (= state expected)
                          @(a/invoke exchange-code (merge @wf-state args))
                          (throw+ {:type ::invalid-state
                                   :state state
                                   :expected expected
                                   ::te/non-retriable true}))]
           (swap! wf-state merge result)))))

    ;; Wait until we have an access token
    (w/await
     (fn []
       (some? (:access_token @wf-state))))

    @(a/invoke persist-auth @wf-state)
    @wf-state))
```

Internally, the Temporal cluster works using event sourcing and checkpointing the results of
"activities", which are functions dedicated to interacting with the outside world and which should
only be run once. When a running workflow receives a signal to restart, it will replay its internal
state changes and the results of previously run activities.

It is important to understand the way Temporal works, becuase it constrains the way workflows are
built and versioned. Once you get it, it starts being kind of second nature.

## Running

We start Temporal and the application

```
temporal server start-dev
clj -M:dev dev
```

When we navigate to the application, we see the start page

![01-start](01-start.png)

The Temporal codec server at `localhost:8233` has no running workflows.

![03-no-workflows](03-no-workflows.png)

When we click "start authentication", we see the login link.

![02-login](02-login.png)

One workflow is running!

![04-one-workflow](04-one-workflow.png)

Clicking on the link takes us to Google, where we can choose the account...

![05-choose-account](05-choose-account.png)

Add permissions...

![06-permissions](06-permissions.png)

Now we have credentials stored in the databasem, and we can see the "Show spreadsheet" link.

![07-show-spreadsheet](07-show-spreadsheet.png)

The contents of the spreadsheet as JSON

![08-spreadsheet-json](08-spreadsheet-json.png)

The corresponding workflow is now finished. We will click on it.

![09-completed](09-completed.png)

The timeline view shows the time the link was active, the callback signal, and then the
`exchange-code` and `persist-auth` activities.

![10-timeline](10-timeline.png)

Below the timeline there is an Event History section. It shows a sequence of events which compose the worklflow execution. `WorkflowExecutionStarted`, `WorkflowExecutionSignaled`, `WorkflowExecutionSignaled` record the arguments passed into and out of the workflow.  

Similarly, `ActivityTaskScheduled` and `ActivityTaskCompleted` record arguments passed into and out of any activites that the workflow calls.

Many events in this workflow were replayed twice: 

![10-event-history](10-event-history.png)

In our example, the first few events were replayed twice:  once when we started the workflow, and once when we continued it. 

Let's look at the `WorkflowExecutionCompleted` event to see workflow output:

![11-nippy](11-nippy.png)

We can't see anything! The result shown here is base64-encoded, nippy-encoded edn data. 

Temporal can issue a CORS request to a "codec server" to decode this for display. I wrote a simple
codec server ring handler which `thaw`s the payload data and sends the result over the wire.

![12-codec-server](12-codec-server.png)

Once selected, the browser will fire off `OPTIONS` and `POST /codec/decode` requests.

![13-decoded](13-decoded.png)

The decode version shows the contents of the `state` atom, which we returned from the workflow.

## What we did

1. Started a workflow, created a state
2. 

## Caveats

Clojure stack traces are long, and Temporal re-runs workflows fast and often, so it's doubly hard to
find out what's going on from looking at the logs. The Temporal UI helps a lot here. In practice,
I'm looking more at the UI and less at the logs. 

In some cases stack traces are exceeding the maximum size allowable by Temporal, which is something
I need to look into more.

Workflow code is loaded when the Temporal worker starts; to reload code, I have to reload the
application's middleware. Biff provides a refresh task for this purpose which does the trick,
meaning it's not necessary to quit the REPL. It's still not as fluid as it woudl otherwise be.

On the flip side, the retries provided by Temporal can make the REPL experience kind of magical too:
if I define a var for debugging, it will get a value from one of the retries right away. I dont'
have to leave the editor.

## Conclusions

This fragmentation isn’t unique to OAuth2 workflows. Many developers and platforms have struggled
with the need for a more compact way to describe asynchronous processes. This is evident in the rise
of low-code tools like Make and n8n, designed to simplify workflows by consolidating such processes.

Included a ring async handler arity in the middleware. This may be enough to work this async-nes
into the code.

We will try an approach that feels very synchronous. In the large, Temporal is a workflow
