---
title: 'Curl: the "c" is for crying'
date: 2022-05-15T11:41:47-05:00
draft: true
---

APIs, or "Application Programing Interfaces", have become the standard way to
join up systems on the Internet. 

Combining APIs is a great way to build a product, and maybe even start a
business. Want to connect your window blinds to the weather.com API? Sure. Want
to do something else with some other thing? Go for it.

Exploring APIs and keeping a record of what you discover has become a basic
task. However, the industry-standard tools for exploring these systems for that
kind of exploration.

Data science notebooks, despite their issues, are still aroudn beause they solve
this workflow very well: code, see a preview, combine results between steps. 
Interspersed with notes.

In this article, we will explore two notebook-like tools for exploring APIs. The first
alternative is Rest Client for Visual Studio Code. In a follow-up post, we will
look at restclient.el for Emacs Org mod. I
have found this "Literate API development" greatly pay off. 

## Postman, cURL and their discontents

In a previous life, my team and I used to be really into Postman for the initial
steps of writing applications. It was good for firing off a few requests and
getting a feel for how an API worked. Over time, Postman collections found their
way into VC repositories, zip files in shared drives, Slack... kind of
everywhere. We were happy customers.

However, like many applications over the last few years, Postman went through a
period of excitement over Electron and ballooned into a whopping 800+ MB
mountain of Javascript. In my team, which had a ton of shared project, for up to
30 seconds at a time. (This probably had something to do with my team abusing it
with a common account and dozens of environments, but still.) It felt like a
flow destroying laptop warmer.

(NB: From what I see, the newest client is leaner, and Postman is now accessed
through a browser.)

So we went back to cURL. It's amazingly portable. It's usually a one-liner, so
it's possible to copy & paste a command and have it work. Postman exports cURL
commands directly from the UI, we stored those in a file and shared the file.

Things start to break in particular ways with cURL, though. Consider these
contrived but common scenarios:

1. Multi-step flows, where the response from one API goes into a second request.
2. When you are POSTing large payloads to JSON APIs.
3. When you, erm, have to remember what you've done before.

I'll share my current worklow based around Visual Studio Code and Emacs Org mode.

In my use cases, it's happily replaced both Postman and cURL. I hope to leave
you with an idea about how it fits together as a simple effetive system for
hacking away at APIs right in a text editor 

## Example task: login

Let's set up a typical exploratory task. We'll set it up using cURL
commands; then we'll bring the same commands into VS Code, and combine them 
with other markup.

We mentioned OAuth earlier. To do anything useful with an OAuth API, you need to
log on and then send a request:

Step 1: Authenticate and get a bearer token.
Step 2: Send that bearer token in a header and get a resource.

This is how it might work in the terminal. First, you send a cURL command with
a username and password,

```shell
curl -u "someapplication:password" \
    -X GET "http://httpbin.org/basic-auth/someapplication/password" \
    -H "accept: application/json"

```

which returns a token

```
{
    "authenticated": "true",
    "token" : "123"
}
```

In the terminal, you copy this token and put it in a variable:

```
TOKEN=123
```

Then you use the token in each authenticated call:

```
curl -i \
    -H "Authorization: Bearer $TOKEN" \
    -H "accept: application/json" \
    -XGET https://httpbin.org/bearer
```

For the request body, you will want to create a small file called
`request.json`. Then put your POST body in it:

```
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


Second, youw will craft a cURL call to send that off as a request body with =@=:

```
curl -i -H "Content-Type: application/json" \
    -XPOST http://httpbin.org/post \
    -H "Authorization: Bearer $TOKEN" \
    -d "@request.json"
```

Now you may have three things to keep track of: a token, a small JSON snippet,
and a command. Not so convenient now!

Both of these can be solved with Postman, which has scripting capabilities and
sharing. Pretty soon you're gonna want to version your code, though; also your
code is tied to a proprietary client.

Wouldn't it be great if we we could write these commands in a plain text file,
easily versioned, where I could execute any of the above the commands
independently and see the results? 

## Literate API development part 1: It's all in the IDE

First, we will replicate the flow above using [Rest Client][rc], available for
Visual Studio Code. In a file called `apis.rest`, write write the following: 

```text
# Auth Example

# @name login
GET http://httpbin.org/basic-auth/someapplication/password
Authorization: Basic someapplication:password

### 
@token = {{login.response.body.user}}
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

Considerably cleaner than the cURL requests above. Also, we can execute any of
the commands independently or in sequence. If we execute the `GET /bearer` call,
the tool is smart enough to notice it has a dependency on the login call. It
will login first, then get the token from the response, and send it off to the
next call.

This text file can be versioned and read in Github as living documentation of 
interactions with the API. The document can be annotated, making it even more
valuable as reference.

There are some limitations to this tool, though. First, the API client itself
does not support all the features of cURL. If we encounter a call which is not
supported, we have no option but to put it in a separate document, or in a
comment. Second, although the results of evaluation can be saved to a file, they
are not in the source file itself. 

[rc]: https://marketplace.visualstudio.com/items?itemName=humao.rest-client
