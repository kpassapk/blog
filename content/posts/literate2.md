---
title: "Literate APIs with Emacs and Org Mode"
date: 2022-05-15T17:37:47-05:00
draft: false
---

In the last [post]({{< ref "literate1.md" >}}), we looked at the Rest Client
extension for VS Code. We started taking a "literate" approach to exploring
APIs, where our interactions are recorded in a text file with a simple format
which can be shared with colleagues and is readable without any special tools.
In this article, we will look at some Emacs features that achieve this and
more.

## Org-mode

Starting as a note taker, [Org mode][org] is today used for agendas and GTD
systems, writing Ph.D theses, and publishing blogs like this one.

Superficially, Org mode is an outline system alla Markdown:

```
 * Heading 1
 Blah blah
 ** Heading 2
 Bleh bleh
```

You have markup for font styles like bold and italic, formatted code snippets,
and can export to HTML. In Markdown, if you want to do anything more, you will
need to select a dialect (commonly known as a flavor) and tools which understand
that dialect. New features are added now and then, but are not compatible across
flavors. For instance, Github just released [math][github-math] equation support
to their Markdown [flavor][ghmarkdown].

Org Mode lacks a specification as such, and its extremely rich feature set is
backed up by its one true reference implementation: 22,000 lines of Emacs lisp
(plus extensions). That Markdown feature just launched by Github? It's been in
Org Mode for at least [15 years][orgmath].

Org mode is one of the more viable solutions for doing literate programming, where
code exists inside prose, rather than prose being inside the code as comments.

Code snippets in Org Mode are written like this:

```
 #+begin_src {{language}}
 {{code}}
 #+end_src
```

They can pass values between them, like in this example:

```
 #+NAME: hi
 #+BEGIN_SRC sh
 echo "hi"
 #+END_SRC

 #+BEGIN_SRC sh :stdin hi
 cowsay
 #+END_SRC
```

We have two source code blocks, and one is getting the output from the other.
They are both running shell scripts. When we run them, we see this:

```
#+NAME: hi
#+BEGIN_SRC sh
echo "hi"
#+END_SRC

#+BEGIN_SRC sh :stdin hi
cowsay
#+END_SRC

#+RESULTS:
:  ____
: < hi >
:  ----
:         \   ^__^
:          \  (oo)\_______
:             (__)\       )\/\
:                 ||----w |
:                 ||     ||

```

It's a little like Markdown, but it's also like a Jupyter notebook. I execute a
"cell" by executing a source block with a keystroke, and that outputs a results
section which is not meant to be edited by hand, since it's regenerated every
time.

## Restclient

RFC 2616 client syntax can be used in Emacs [restclient][restclient]
by embedding it in a block with language `restclient`.

```
#+NAME: restclient
#+begin_src restclient :results value
POST http://httpbin.org/post
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
#+end_src
```
> *NB: The request body in this example is made up.*

Now let's introduce a second code block, which reads the output of the first,
and manipulates it. We will use both bash and Python, thanks to the
[babel][org-babel] extension, built into Emacs.

```
#+begin_src sh :stdin restclient :wrap src json
jq '.'
#+end_src

#+RESULTS:
#+begin_src json
{
  "args": {},
  "data": "{\n    \"jql\": \"project = HSP\",\n   ... }"
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    ...
  },
  "json": {
    "fields": [
      "summary",
      "status",
      "assignee"
    ],
    "jql": "project = HSP",
    "maxResults": 15,
    "startAt": 0
  },
  "origin": "190.140.132.62",
  "url": "http://httpbin.org/post"
}
#+end_src
```

This block uses [jq][jq] to pretty print the output. Now let's write another
`jq` block, this time extracting the contents of the `data` entry, which
contains the original payload.

```
#+NAME: json-doc
#+begin_src sh :stdin restclient :wrap src json
jq -r .data
#+end_src

#+RESULTS: json-doc
#+begin_src json
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
#+end_src
```

The payload has been unescaped by `jq`. Pretty neat. Something that JQ doesn't
do? No problem, let's pipe that through a Python function.

```
#+begin_src python :var jsondoc=json-doc :wrap src json
import json
data = json.loads(jsondoc)
print(json.dumps(data, indent=4))
#+end_src

#+RESULTS:
#+begin_src json
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
#+end_src
```

It may not be obvious reading this how automated this actually is. The code
snippets are executable at a keystroke for either the shell-based `jq` or
Python. 

The data science community has been developing multi-language versions for years
that can do much the same thing. Unlike data science notebooks, here we never
leave the editor, and there is no content vs. container format distinction. It's
all in a text file with some markup that still looks OK when you read it in
plain text.

If you were to load it in Org mode, you would see nice syntax highlighting for
the code in the blocks, and be able to jump into each snippet in a separate
window to edit with syntax checking and linting support. You can even use
[LSP][org-lsp] in the fragments to gain sophisticated static analysis
capabilities. If you don't, there is improving support in [other][org-vim]
[editors][org-vscode].

To get the most of it, though, you have to embrace Emacs. Once you do, you will
find there's no context switch between the editor and the document, or between
the document the embeddd code snippets. If you invest time to get it to work,
the rewards are many. I use [doom emacs][doom] almost out of the box; it's never
been easier to start using Emacs without knowing Emacs Lisp.

# Caching

Let's keep going with something that would have made the cURL or Postman
workflow really strain. We will make requests against an API that returns a
large response. We'll use the Pokemon API as an example.

With such a large payload, we want to see if we can capture it once, and then
slice and dice it several ways. This is done by enabling caching. We will put
the entire output in a _drawer_, which can be hidden from view.[^1]

[^1]: The drawer may get in the way of the results parsing. The workaround is just to add an extra line before the closing tag.

```
#+NAME: pokemon-cached
#+begin_src restclient  :results value drawer :cache yes
GET https://pokeapi.co/api/v2/pokemon-species/25/
Accept: application/json
#+end_src
```

The drawer contains a large amount of text. How much exactly?

```
#+begin_src sh :stdin pokemon-cached :results output
wc
#+end_src

#+RESULTS:
:     4051   10049  133247
```

4051 lines. This last command should have executed instantly, since it's
working off a cached response from the REST call.

With large responses such as this one, it can be hard to get what the overall
structure is like, at a glance. Let's use `jq` to create a few summaries of the
document.

```
#+begin_src sh :stdin pokemon :wrap src json
jq 'keys'
#+end_src
```

```
#+RESULTS:
#+begin_src json
[
  "base_happiness",
  "capture_rate",
  "color",
  ... 15 more ...
  "is_baby",
  "is_legendary",
  "is_mythical",
  "name",
  "names",
  "order",
  "pal_park_encounters",
  "pokedex_numbers",
  "shape",
  "varieties"
]
#+end_src
```

Now let's look at the first item in the `names` array. 

```
jq '.names[0]'
#+end_src

#+RESULTS:
: {
:   "language": {
:     "name": "ja-Hrkt",
:     "url": "https://pokeapi.co/api/v2/language/1/"
:   },
:   "name": "ピカチュウ"
: }
```

This is telling us what Pikachu is called in a few different languages. We can
get a results table by passing the results stream through the `@csv` filter:

```
#+begin_src sh :stdin pokemon-cached :wrap src csv
jq -r '.names[] | [.name, (.language | .name, .url)] | @csv'
#+end_src
```

```
#+RESULTS:
#+begin_src csv
| ピカチュウ   | ja-Hrkt | https://pokeapi.co/api/v2/language/1/  |
| Pikachu    | roomaji | https://pokeapi.co/api/v2/language/2/  |
| 피카츄      | ko      | https://pokeapi.co/api/v2/language/3/  |
| 皮卡丘      | zh-Hant | https://pokeapi.co/api/v2/language/4/  |
| Pikachu    | fr      | https://pokeapi.co/api/v2/language/5/  |
| Pikachu    | de      | https://pokeapi.co/api/v2/language/6/  |
| Pikachu    | es      | https://pokeapi.co/api/v2/language/7/  |
| Pikachu    | it      | https://pokeapi.co/api/v2/language/8/  |
| Pikachu    | en      | https://pokeapi.co/api/v2/language/9/  |
| ピカチュウ   | ja      | https://pokeapi.co/api/v2/language/11/ |
| 皮卡丘      | zh-Hans | https://pokeapi.co/api/v2/language/12/ |
#+end_src
```

The resulting table could be further processed by a Python source code block, or
output to a file. Once you have a few things down about the shape of the data,
you would probably want to remove the cached response from your document and
removed the `:cache yes` option.

# Emacs Lisp

This is all pretty much out-of-the-box Emacs. Things get a bit more interesting
when we teach Emacs a few new tricks. Since Babel has support for Emacs Lisp as
a language, we can define functions in in the document, which when evaluated
will add to or modify the document. Let's see for example a code block which
prints the current heading.

```
#+begin_src elisp :results value
(org-entry-get nil "ITEM")
#+end_src

#+RESULTS:
: Emacs Lisp
```

We can use this technique to run the [example]({{< ref "literate1.md#example" >}}) 
call from the previous post.

First, we'll write a cURL command which does basic authentication against an API
and returns a token. Then we'll use elisp to store that token in a hidden field
in the document. Then in a second call, we will use the stored token and
send it using restclient to another API.

This is the `save-login` function, which saves the login to a header argument:

```
#+NAME: save-login
#+begin_src elisp
(org-set-property "header-args+" (concat ":var token=" (json-encode (chomp token))))
#+end_src
```

We will explain how to get the `token` variable in a bit. The "chomp" function
is from the [Emacs lisp cookbook][elisp-cookbook]. Similar to the one in Perl,
it removes leading and trailing whitespace.

The `save-login` function gets a token and saves it in a "header argument" with
this format:

```
#+begin_example
 :header-args+: :var token="3af41..."
#+end_example
```

If you're not into Emacs (yet), the details won't make much sense. Let's just
say that this header argument is what will let you recall the token later on.

Now we need the actual API calls to do the login:

```
#+name: basicauth
#+begin_src shell
curl -u "someapplication:password" \
    -X GET "http://httpbin.org/basic-auth/someapplication/password" \
    -H "accept: application/json"
#+end_src

#+RESULTS: basicauth
: {
:   "authenticated": true,
:   "user": "someapplication"
: }
```

For now, let's assume we got a token back from the API. We'll fake it by base64
encoding the username to look like a token :)

```
#+name: token
#+begin_src sh :stdin basicauth
jq '.user' | base64
#+end_src

#+RESULTS: token
: InNvbWVhcHBsaWNhdGlvbiIK
```

Now we call our `save-login` function.

```
#+begin_src example
#+call: save-login :var token=token
#+end_src
```

The header argument of the notebook now contains a property.

```
#+begin_example
 ** Emacs Lisp
 :PROPERTIES:
 :header-args+: :var token="InNvbWVhcHBsaWNhdGlvbiIK"
 :END:
#+end_example
```

Anything else under this subheading of the document will be able to use the
token by just referring to it. Let's pretend we're giving it to another API call
via REST Client, by placing it in an HTTP header.

```
#+begin_src restclient
GET https://httpbin.org/bearer
accept: application/json
Authorization: Bearer :token
#+end_src
```

```
#+RESULTS:
#+BEGIN_SRC js
{
  "authenticated": true,
  "token": "InNvbWVhcHBsaWNhdGlvbiIK"
}
```
Since the `token` was in the `header-args` list, it could be used from the source block without 
having to require it explicitly.

I find I use this approach a lot to remember the authentication credentials for
an API, and having the credentials available to every code block in the
document.


# Conclusions

We can adopt "Literate API development" by embedding executable `restclient`
blocks into Emacs Org Mode, together with tools like `jq` or scripting languages
like Python. By using caching a few helper functions for authentication, it
becomes possible to explore large APIs and record those explorations. 

Since the commands, request and response data are all stored in a plain text
document, it is easy to share with colleagues or export to a blog or
documentation page. This blog post is an example: the code blocks you see above
were executed in-place, and the blog content was exported with [ox-hugo][ox-hugo].

A nice extension could be to deepen the integration of the rest client, `jq` and
Org Mode. For instance, we could have have elisp understand the `jq` syntax, so
that table headings would be automatically inserted by reading the filter.

Another interesting addition would be to turn both the REST Client code and the
`jq` filters into Go or Python code. The REST client code would be translated
into HTTP library calls; `jq` could be turned into loops or list comprehensions.
This way, the exploratory work could be used right away to start building 
production code, without having to guess at the data formats being returned by 
the APIs.

[org]: https://orgmode.org/
[ghmarkdown]: https://github.github.com/gfm/
[org-latex]: https://orgmode.org/manual/LaTeX-fragments.html
[github-math]: https://github.blog/2022-05-19-math-support-in-markdown/
[orgmath]: https://orgmode.org/manual/LaTeX-math-snippets.html
[jq]: https://stedolan.github.io/jq/
[restclient]: https://github.com/pashky/restclient.el
[org-babel]: https://orgmode.org/worg/org-contrib/babel/
[elisp-cookbook]: https://www.emacswiki.org/emacs/ElispCookbook
[org-lsp]: https://emacs-lsp.github.io/lsp-mode/manual-language-docs/lsp-org/
[org-vscode]: https://github.com/vscode-org-mode/vscode-org-mode
[org-vim]: https://github.com/jceb/vim-orgmode/blob/master/CHANGELOG.org
[doom]: https://github.com/doomemacs/doomemacs
[ox-hugo]: https://ox-hugo.scripter.co/

