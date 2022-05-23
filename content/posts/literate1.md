---
title: 'Curl: the "c" is for crying'
date: 2022-05-15T11:41:47-05:00
---

APIs, or "Application Programing Interfaces", have become the standard way to
join up systems on the Internet. 

APIs are great for constructing interesting interactions between systems we own.
Want to connect your window blinds to Alexa, so that they can be opened and
closed on command? Chances are, you can do that with APIs.

APIs are serious business, too. The major public clouds are API-driven concerns
worth trillions in aggregate. Companies have been busy exposing APIs since
around the time moble apps became a thing. Along the way, many more profitable
businesses have discovered that even if they're not in the software industry, 
they can exploit this method of software delivery [to great effect][hbr]

As a developer, this is an exciting trend. Indeed, exploring APIs should be an
essential part of your daily work, just as much as deepening your understanding
of your programming language of choice.

I typically use notebooks to keep track of whatever I'm learning, so that I can
come back at any point and revisit. often find myself searching through old
notes for something I had seen before.

For the longest time, I wasn't able to make API exploration "notebook-friendly".
Partly this is because the most popular tools, cURL and Postman, are not made 
with this end in mind.

A few new tools have made it possible to take a notebook-driven approach even
when exploring external APIs. These toold enable "Literate API development", a
great way of developing connected applications.

This is a two-part series. In this post, we develop Literate API notebooks using
VS Code and an extension called Rest Client. Then we'll take it a beet deeper
and jump into Emacs [Org Mode][org].

## Postman, cURL and their discontents

In a previous life, my team and I used to be really into Postman for the initial
steps of writing applications. It was good for firing off a few requests and
getting a feel for how an API worked. Over time, Postman collections found their
way into VC repositories, zip files in shared drives, Slack... kind of
everywhere. We were happy customers.

However, like many applications over the last few years, Postman went through a
period of excitement over Electron and ballooned into a whopping 800+ MB
mountain of Javascript. The app was unresponsive for up to 30 seconds at a time.
(This probably had something to do with my team abusing it with a common account
and dozens of environments, but still.) It felt like a flow destroying laptop
warmer.

> NB: From what I see, the newest client is leaner, and Postman is now accessed
> through a browser.

So we went back to cURL. It's amazingly portable. It's usually a one-liner, so
it's possible to copy & paste a command and have it work. Postman exports cURL
commands directly from the UI, we stored those in a file and shared the file.

Things start to break in particular ways with cURL, though. Consider these
contrived but common scenarios:

1. Multi-step flows, where the response from one API goes into a second request.
2. When you are POSTing large payloads to JSON APIs.
3. When you, erm, have to remember what you've done before.

Let's set up a typical task using cURL commands. Then we'll bring the same
commands into VS Code, and combine them with other markup.

## Example task: login {#example}

To do anything useful with an API, you need to log on and then send a request.
In a typical scenario, this consist of the following two steps: [^1]

[^1]: This would be close to the usage in OAuth Client Credentials grant.

Step 1: Authenticate and get a bearer token.
Step 2: Send that bearer token in a header and get a resource.

This is how it might work in the terminal. First, you send a cURL command with
a username and password using Basic HTTP Auth. 

```shell
$ curl -u "someapplication:password" \
    -X GET "http://httpbin.org/basic-auth/someapplication/password" \
    -H "accept: application/json"
```

which returns a token, say like this

```json
{
    "authenticated": "true",
    "user": "someapplication",
    "token" : "123"
}
```

> *NB: HTTPbin does not actually return a token from this call, but real 
> APIs would.*

In the terminal, you copy this token and put it in an environment variable:

```shell
$ TOKEN=123
```

Then you use the token in each authenticated call:

```
$ curl -i \
    -H "Authorization: Bearer $TOKEN" \
    -H "accept: application/json" \
    -XGET https://httpbin.org/bearer
```

For the request body, you will want to create a file called `request.json`. Then
put your POST body in it:

```json
{
    "jql": "project = HSP",
    "startAt": 0,
    "maxResults": 15,
    "fields": [
        "summary",
        "status",
        "assignee"
    ]
}
```

Second, youw will craft a cURL call to send that off as a request body with `@`:

```shell
$ curl -i -H "Content-Type: application/json" \
    -XPOST http://httpbin.org/post \
    -H "Authorization: Bearer $TOKEN" \
    -d "@request.json"
```

> *If you are not familiar with cURL or with the command line, read
> on: we will be using a simpler syntax in the next section.*

Now you may have three things to keep track of: a token, a small JSON snippet,
and a command. Easily solved in a Shell script, but we lose out in exploration
and one-liner-ness. Whereas before each command was executable by itself, now
they depend on each other. We have to remember to run the login task and store
the token before we continue exploration.

It may seem like it's not a big deal, but it breaks flow. Precious flow, which
we need to keep intact for more interesting tasks! Try and come back to this
months later, and you may be staring at your screen for a little while, trying
to figure it out again. 

I often find that when I come back months later, I just want to see what the API
responded back when I was playing with it. I'm not interested in making new
requests, just checking up on the schema of what was returned. By itself, cURL
helps us not at all here.

This is enough of a problem that a few GUI tools have cropped up, adding a
richer workflow. [Postman][postman] adds scripting capabilities and sharing,
which can work if you really want to log into something you would rather do
right in your editor, if you don't mind mild to severe slowdown we have already
covered, and if you don't mind your testing code tied to a proprietary client.

Oh, and pretty soon you're gonna want to version this code. So things are
looking pretty far from OK from where I'm looking at it. Luckily, some simple
tools for editors have come up that are much less intrusive.

## Rest Client for Visual Studio Code

To replicate the flow above using [Rest Client][rc], available for Visual Studio
Code. write write the following ina file called `apis.rest`

```text
# @name login
GET http://httpbin.org/basic-auth/someapplication/password
Authorization: Basic someapplication:password

@token = {{login.response.body.user}} # httpbin doesn't return 'token'!

### 
GET https://httpbin.org/bearer

###

POST https://httpbin.org/post
Authorization: Bearer {{token}}
Content-Type: application/json

{
    "jql": "project = HSP",
    "startAt": 0,
    "maxResults": 15,
    "fields": [
        "summary",
        "status",
        "assignee"
    ]
}
```

This file has three code blocks, each one written in plain text using a format
defined by [RFC 2616][rfc2616]. The request method (GET / POST) is specified in
the first line, followed by the endpoint. Headers and request body (if any)
follow, separated by a blank line.

Rest Client is able to pass a token by reading the JSON response of the API
login call and extracting the token.[^2]

[^2]: As noted earlier, HTTPBin doesn't return a token, so we're using the user field instead.

This is considerably cleaner than the cURL requests above. We can execute any of
the commands independently or in sequence. If we execute the `GET /bearer` call,
the tool is smart enough to notice it has a dependency on the login call. It
will login first, then get the token from the response, and send it off to the
next call.

This text file can be versioned and read in Github as living documentation of
interactions with the API. The document can be annotated, making it even more
valuable as reference. Editor features such as autocompletion are nicely
implemented. When run, a sample of the output of every call can be saved to a
file. Instand documentation of what matters most!

There are some limitations to this tool, though. First, the API client itself
does not support all the features of cURL. If we encounter a call which is not
supported, we have no option but to put it in a separate document, or in a
comment. Second, although the results of evaluation can be saved to a file, they
are not in the source file itself. The `.http` extension is only readable (as
far as I know) by this plugin, and will appear as a text file anywhere else. It
would have been nice if the file was Markdown-compatible, for instance, so that 
other editors could see a rendered version of the document, complete with code
blocks.

To get many of these features, and more, let's have a look at what we can get 
with Emacs Org Mode.

[postman]: https://www.postman.com/
[rfc2616]: https://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
[org]: https://orgmode.org/
[hbr]: https://hbr.org/2021/04/apis-arent-just-for-tech-companies
[rc]: https://marketplace.visualstudio.com/items?itemName=humao.rest-client
