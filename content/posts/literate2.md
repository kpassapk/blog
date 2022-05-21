---
title: "Literate APIs with Emacs and Org Mode"
date: 2022-05-15T17:37:47-05:00
draft: true
---

In the last [post]({{< ref "literate1.md" >}}), we looked at an extension
for Visual Studio Code called "Rest Client". We tlaked a bit about the benefits
to taking a "literate" approach to exploring APIs, where your interactions are 
recorded in a text file with a simple format which you can share with colleagues
and is readable without any special tools. In this article, we will look at some
tools for Emacs.

## Org-mode

Next to Donald Knuth with LaTeX, Dominic Carsten should go down in history as
one of the greatest yak-shavers of all time. Starting as a note taker, Org mode
is today used for agendas and GTD systems, writing Ph.D theses, and publishing
blogs like this one.

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
Org Mode for about [15 years][orgmath].

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

We have two source code blocks, and one is getting the otuput from the other.
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

So it's a little like Markdown, but it's also like Jupyter. I execute a "cell"
by executing a source block with a keystroke, and that outputs a results section
which is not meant to be edited by hand, since it's regenerated every time.

There's a lot more to org-mode, but we have enough for the curious to start I
hope.

## Restclient

The same RFC 2616] client syntax can be used in Emacs [restclient][restclient]
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

Following the org example above, we will introduce a second code block, which
reads the output of the first, and manipulates it. We will use both bash and
Python, thanks to the [babel][org-babel] extension, built into Emacs.

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
containins the original payload.

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

The payload has been unescaped by JQ. Pretty neat. Something that JQ doesn't do?
No problem, let's pipe that through a short Python function.

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
all in a big text file with some markup that still looks OK when you read it in
plain text.

If you were to load it in Org mode, you would see nice syntax highting for the
code in the blocks, and be able to jump into each snippet in a separate window
to edit with indentation, linting, and documentation. You can even use
[LSP][org-lsp] in the fragments to gain sophisticated static analysis
capabilities. If you don't, there is improving support in [other][org-vim]
[editors][org-vscode].

To get the most of it, though, you have to embrace that this thing is completely
tied into Emacs. There's no context switch between the editor and the document,
or between the document the embeddd code snippets. If you invest time to get it
to work, the rewards are many. I use [doom emacs][doom] almost out of the box.

# Caching

Let's keep going with something that would have made the cURL or Postman
workflow really strain. We will make requests against an API that returns a
large response. We'll use the Pokemon API as an example.

With such a large payload, we want to see if we can capture it once, and then
slice and dice it several ways. This is done by enabling caching. The resulting
header will be like this:

```
#+begin_src restclient :results value drawer :cache yes
```

We're going to want to use this cache in later steps. A footnote here: first,
the drawer gets in the way of the results parsing. This can be overcome through
scripting, but the workaround is just to shift the output by 1 line. (More in
notes section, along with the workaround.)

```
#+NAME: pokemon-cached
#+begin_src restclient  :results value drawer :cache yes
GET https://pokeapi.co/api/v2/pokemon-species/25/
Accept: application/json
#+end_src
```

The top of the results drawer looks like this:
```

 :results:
 #+RESULTS[af90d0f88686fd6432b6b25e0f7764fad2413481]: pokemon-cached
 {
   "base_happiness": 70,
   "capture_rate": 190,
   "color": {
     "name": "yellow",
     "url": "https://pokeapi.co/api/v2/pokemon-color/10/"
   },
   ... ~ 4,000 more lines ...

```

But when I collapse it with Emacs, it's unintrusive:

#+attr_org: :width 800
[[attachment:_20210621_195727screenshot.png]]

It's gone from line 192 to line 4246. That's a pretty big JSON payload.
How big exactly?

```
#+begin_src sh :stdin pokemon-cached :results output
wc
#+end_src

#+RESULTS:
:     4051   10049  133247
```

4051 lines. This last command should have executed instantly, since it's
working off a cached response from the REST call. It only had to 

It's pretty hard to grok the overall structure and contents, though, so let's
use `jq` again.

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
  "egg_groups",
  "evolution_chain",
  "evolves_from_species",
  "flavor_text_entries",
  "form_descriptions",
  "forms_switchable",
  "gender_rate",
  "genera",
  "generation",
  "growth_rate",
  "habitat",
  "has_gender_differences",
  "hatch_counter",
  "id",
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

This API has some scalars like =name=, and some lists like =names=:

#+begin_src sh :stdin pokemon-cached :results output
jq '.name'
#+end_src

#+RESULTS:
: "pikachu"

#+begin_src sh :stdin pokemon-cached :results output
jq '.names | length'
#+end_src

#+RESULTS:
: 11

#+begin_src sh :stdin pokemon-cached :results output
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

Now let's try and output all the 11 translations as a table.

#+begin_src sh :stdin pokemon-cached :wrap src csv
jq -r '.names[] | [.name, (.language | .name, .url)] | @csv'
#+end_src

#+RESULTS:
#+begin_src csv
| ピカチュウ | ja-Hrkt | https://pokeapi.co/api/v2/language/1/  |
| Pikachu    | roomaji | https://pokeapi.co/api/v2/language/2/  |
| 피카츄     | ko      | https://pokeapi.co/api/v2/language/3/  |
| 皮卡丘     | zh-Hant | https://pokeapi.co/api/v2/language/4/  |
| Pikachu    | fr      | https://pokeapi.co/api/v2/language/5/  |
| Pikachu    | de      | https://pokeapi.co/api/v2/language/6/  |
| Pikachu    | es      | https://pokeapi.co/api/v2/language/7/  |
| Pikachu    | it      | https://pokeapi.co/api/v2/language/8/  |
| Pikachu    | en      | https://pokeapi.co/api/v2/language/9/  |
| ピカチュウ | ja      | https://pokeapi.co/api/v2/language/11/ |
| 皮卡丘     | zh-Hans | https://pokeapi.co/api/v2/language/12/ |
#+end_src

We can also put in headings. Again we're using the cached copy.

#+begin_src sh :stdin pokemon-cached :wrap org drawer
jq -r '["Name", "Language name", "Language URL"], (.names[] | [.name, (.language | .name, .url)]) | @csv'
#+end_src

#+RESULTS:
#+begin_org drawer

| ピカチュウ | ja-Hrkt       | https://pokeapi.co/api/v2/language/1/  |
| Pikachu    | roomaji       | https://pokeapi.co/api/v2/language/2/  |
| 피카츄     | ko            | https://pokeapi.co/api/v2/language/3/  |
| 皮卡丘     | zh-Hant       | https://pokeapi.co/api/v2/language/4/  |
| Pikachu    | fr            | https://pokeapi.co/api/v2/language/5/  |
| Pikachu    | de            | https://pokeapi.co/api/v2/language/6/  |
| Pikachu    | es            | https://pokeapi.co/api/v2/language/7/  |
| Pikachu    | it            | https://pokeapi.co/api/v2/language/8/  |
| Pikachu    | en            | https://pokeapi.co/api/v2/language/9/  |
| ピカチュウ | ja            | https://pokeapi.co/api/v2/language/11/ |
| 皮卡丘     | zh-Hans       | https://pokeapi.co/api/v2/language/12/ |
#+end_org

This table has been created directly from the API response. I never had to leave
the editor, copy & paste data or anything. Similarly, we can have a look at the
other two collections in the API, for Pokemon varieties and Pokedex numers
(whatever that is.)

#+begin_src sh :stdin pokemon :wrap src csv :hlines yes
jq -r '.varieties[] | [ .pokemon | .name, .url ] | @csv'
#+end_src

#+RESULTS:
#+begin_src csv
| pikachu              | https://pokeapi.co/api/v2/pokemon/25/    |
| pikachu-rock-star    | https://pokeapi.co/api/v2/pokemon/10080/ |
| pikachu-belle        | https://pokeapi.co/api/v2/pokemon/10081/ |
| pikachu-pop-star     | https://pokeapi.co/api/v2/pokemon/10082/ |
| pikachu-phd          | https://pokeapi.co/api/v2/pokemon/10083/ |
| pikachu-libre        | https://pokeapi.co/api/v2/pokemon/10084/ |
| pikachu-cosplay      | https://pokeapi.co/api/v2/pokemon/10085/ |
| pikachu-original-cap | https://pokeapi.co/api/v2/pokemon/10094/ |
| pikachu-hoenn-cap    | https://pokeapi.co/api/v2/pokemon/10095/ |
| pikachu-sinnoh-cap   | https://pokeapi.co/api/v2/pokemon/10096/ |
| pikachu-unova-cap    | https://pokeapi.co/api/v2/pokemon/10097/ |
| pikachu-kalos-cap    | https://pokeapi.co/api/v2/pokemon/10098/ |
| pikachu-alola-cap    | https://pokeapi.co/api/v2/pokemon/10099/ |
| pikachu-partner-cap  | https://pokeapi.co/api/v2/pokemon/10148/ |
| pikachu-gmax         | https://pokeapi.co/api/v2/pokemon/10190/ |
#+end_src

#+begin_src sh :stdin pokemon :wrap src csv
jq -r '.pokedex_numbers[] | [.entry_number, (.pokedex | .name, .url)] | @csv'
#+end_src

#+RESULTS:
#+begin_src csv
|  25 | national          | https://pokeapi.co/api/v2/pokedex/1/  |
|  25 | kanto             | https://pokeapi.co/api/v2/pokedex/2/  |
|  22 | original-johto    | https://pokeapi.co/api/v2/pokedex/3/  |
| 156 | hoenn             | https://pokeapi.co/api/v2/pokedex/4/  |
| 104 | original-sinnoh   | https://pokeapi.co/api/v2/pokedex/5/  |
| 104 | extended-sinnoh   | https://pokeapi.co/api/v2/pokedex/6/  |
|  22 | updated-johto     | https://pokeapi.co/api/v2/pokedex/7/  |
|  16 | conquest-gallery  | https://pokeapi.co/api/v2/pokedex/11/ |
|  36 | kalos-central     | https://pokeapi.co/api/v2/pokedex/12/ |
| 163 | updated-hoenn     | https://pokeapi.co/api/v2/pokedex/15/ |
|  25 | original-alola    | https://pokeapi.co/api/v2/pokedex/16/ |
|  25 | original-melemele | https://pokeapi.co/api/v2/pokedex/17/ |
|  32 | updated-alola     | https://pokeapi.co/api/v2/pokedex/21/ |
|  32 | updated-melemele  | https://pokeapi.co/api/v2/pokedex/22/ |
| 194 | galar             | https://pokeapi.co/api/v2/pokedex/27/ |
|  85 | isle-of-armor     | https://pokeapi.co/api/v2/pokedex/28/ |
|  25 | updated-kanto     | https://pokeapi.co/api/v2/pokedex/26/ |
#+end_src

# Org mode hackery

This is all pretty much out-of-the-box Emacs. Things get a bit more interesting
when we teach Emacs a few new tricks. Since Babel has support for Emacs Lisp as
a language, we can define functions in in the document, which when evaluated
will add to or modify the document. Let's see for example a code block which
prints the current heading.

#+begin_src elisp :results value
(org-entry-get nil "ITEM")
#+end_src

#+RESULTS:
: Org mode hackery

(As a disclaimer, my elisp-fu is pretty weak, so for sure all of these things can
be done in a much better way.)

# Multi-step forms
:PROPERTIES:
:header-args+: :var token="InNvbWVhcHBsaWNhdGlvbiIK"
:END:

Let's use this technique to script an API call with two steps. Here's what we'll do:

Fist, we'll write a cURL command which does basic authentication against an API
and returns a token. Then we'll use elisp to store that token in a hidden field
in the document. Finally, in a second call, we will use the stored token and
send it using restclient to another API.

This is the elisp to save the login to a header argument. This is the
=save-login= function:

#+NAME: save-login
#+CAPTION: save-login function
#+begin_src elisp
(org-set-property "header-args+" (concat ":var token=" (json-encode (chomp token))))
#+end_src

We will explain how to get the =token= variable in a bit. The "chomp" function
is from the Emacs lisp cookbook. Similar to the one in Perl, it removes leading
and trailing whitespace. More in the notes section.

The "save-login" function gets a token and saves it in a "header argument" with
this format:

#+begin_example
 :header-args+: :var token="3af41..."
#+end_example

If you're not into Emacs (yet), the details won't make much sense. Let's just
say that this header argument is what will let you recall the token later on.

Now we need the actual API calls to do the login:

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

For now, let's assume we got a token back from the API. We call

#+name: token
#+begin_src sh :stdin basicauth
jq '.user' | base64
#+end_src

#+RESULTS: token
: InNvbWVhcHBsaWNhdGlvbiIK

#+begin_src example
#+RESULTS: token
: InNvbWVhcHBsaWNhdGlvbiIK
#+end_src

Now we call

#+begin_src example
#+call: save-login :var token=token
#+end_src

#+call: save-login(token=token)

The header argument of this article (notebook?) now contians a property.

#+begin_example
 ** Multi-step forms
 :PROPERTIES:
 :header-args+: :var token="InNvbWVhcHBsaWNhdGlvbiIK"
 :END:
#+end_example

What does that give us? Well, anything else in this part of the document will be
able to use the token by just referring to it. Let's pretend we're giving it to
another API call via REST Client, by placing it in an HTTP header.

#+name: bearer-token
#+begin_src restclient
GET https://httpbin.org/bearer
accept: application/json
Authorization: Bearer :token
#+end_src

#+RESULTS:
#+BEGIN_SRC js
{
  "authenticated": true,
  "token": "InNvbWVhcHBsaWNhdGlvbiIK"
}

The token has been passed from one call to the next! Why is this interesting?
Well, we can evaluate every code block in this document, and then have
publishable article with all of the tables, plots (if we had them), recomputed
and inserted back int o the doc. Kind of like a data science notebook, but where
(1) everything is hackable, and (2) there is no separation between content +
tool + markup, as there is with a Jupyter notebook or similar. It's all plain
text and elisp.

## Export

There's a command in restclient, =restclient-copy-curl-command=, to generate a
cURL command from the restclient code and copy the cURL command to the
clipboard. we will add some code here to to to the last command, copy the code,
and then paste it below. (More as a demo of how flexible this scripting can
get.)

#+name: curl
#+begin_src elisp
(org-with-wide-buffer
 (org-babel-goto-named-src-block "bearer-token")
 (restclient-copy-curl-command))
(org-babel-goto-named-result "curl")
(org-insert-structure-template "src")
(insert "sh :results output :var token=token\n")
(insert (car kill-ring-yank-pointer))
#+end_src

It inserted this, which I modified only slightly, replacing =token= with
=$token=, and then ran:

#+results: curl
#+begin_src sh :results output :var token=token
curl -i -H Authorization\:\ Bearer\ $token -H accept\:\ application/json -XGET https\://httpbin.org/bearer
#+end_src

#+RESULTS:
#+begin_example
HTTP/2 200 
date: Tue, 22 Jun 2021 02:47:53 GMT
content-type: application/json
content-length: 68
server: gunicorn/19.9.0
access-control-allow-origin: *
access-control-allow-credentials: true

{
  "authenticated": true,
  "token": "InNvbWVhcHBsaWNhdGlvbiIK"
}
#+end_example

It's easy to get carried away, hacking APIs, responses, and the editor all at
the same time and in the same document. Starting in this document, the Lisp and
other code can take their separate paths: Lisp to go into a function bound to a
key, so that I can use it in any document I like; the REST client an JQ code
could be exported to Python or another programming language, so that I could
put them in production.

Would I recommend it in terms of strict productivity? Perhaps not; it takes a
little while to get started. Is it hella fun and kind of addictive? yes.

# Next steps

There are several ways this could be improved:

- We could have have elisp understand the =jq= syntax, so that table headings
  are automatically inserted by reading the filter.

- We could ensure all steps are idempotent, including cleaning up cached data.
  They *mostly* are right now, but there are a few exceptions.

- We could add an export function to other languages like Python or Go. This
  export function could even take into account the JQ filters in subsequent
  blocks, so that we have both the calling and filtering code available.

* Conclusions

There are a few interesting qualities about this approach for me. The first is
homoiconicity. This is the often touted description of lisp languages, and is
supposed to refer to the symmetry betwen the program's code and the data that it
operates on. For lisps, since the code is a bunch of lists, and the data
structures are also bunch of lists. This is supposed to unleash some real
economies of scale when it comes to code re-use. Or something like that.

From the poitn of view of these exercises, you might say there's a certain more
pedestrian form of homoiconicity at play. The document itself is the srouce, the
intermediate data store, and the target. The document contains the code that
can further modify the document. Maybe not so pedestrian after all.

Given the pretty excellent support for domain specific langauges like
Restclient, and also really good integration for subshells, it's possible to
create arbitrarily complex workflows right in one document that do real work in
the outside world (gasp - outside the document!) all in the flow of text. This
is why this is super-squarely in the world of literate programming. Donald Knuth
would be proud.

Lisp is supposed to be one of those programming languages that you learn in
order to become better at other, real, productive programming languages. In
Emacs, it is just a very practical and very well documented construct that can
be chained up however and wherever. It doesn't produce the fastest code, but
it's endlessly flexible. It was not evident how much this was the case until
working ont hese exercises.

I hope this article gave you a taster of what is possible if you choose to brave
the world of many parens. and having that "fits-like-a-glove environment."

[ghmarkdown]: https://github.github.com/gfm/
[org-latex]: https://orgmode.org/manual/LaTeX-fragments.html
[github-math]: https://github.blog/2022-05-19-math-support-in-markdown/
[orgmath]: https://orgmode.org/manual/LaTeX-math-snippets.html
[jq]: https://stedolan.github.io/jq/
[restclient]: https://github.com/pashky/restclient.el
[org-babel]: https://orgmode.org/worg/org-contrib/babel/
[elisp-cookbook]: https://www.emacswiki.org/emacs/ElispCookbook
[auth0 examples]: https://auth0.com/docs/connections/generic-oauth2-connection-examples
[ceo-emacs]: https://www.fugue.co/blog/2015-11-11-guide-to-emacs.html
[org-lsp]: https://emacs-lsp.github.io/lsp-mode/manual-language-docs/lsp-org/
[org-vscode]: get https://github.com/vscode-org-mode/vscode-org-mode
[org-vim]: https://github.com/jceb/vim-orgmode/blob/master/CHANGELOG.org
[doom]: https://github.com/doomemacs/doomemacs
