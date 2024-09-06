---
title: "Six months with Clojure, from Go"
date: 2023-11-14T20:00:00-05:00
draft: true
---

When I started my consulting company early this year, I wanted it to be with Clojure. As a content citizen of the Go community for a few years, it was not an easy decision.

Six months on, I can say I have gained more than I lost. It's early days yet, but I'm earning enough for the rent with my Clojure dablling. In that time I paid the Lisp tax and the JVM tax down, having no prior experience with either.

I'll share some of my experience on this journey below.

## But Whence Clojure?

Go and Clojure share "simplicity" as a mantra and vision, even if they interpret it in very different ways.

It's healthy to assume that every modern general-purpose langauge is, for all intents and purposes, equally capable. The best decisions are not when there are no tradeoffs, but when you gain more than you lose. (Ray Dalio.) The tradeoffs of Go and Clojure are well documented. 

Choosing a language ultimately comes down to your specific requirements, plus style / aesthetic preference.

In my case, I wanted a faster feedback cycle, and I wanted to get into full stack. As a new solo developer, I needed something which would give me that leverage. Something fast to develop, with reach.

As a small company, my only competitive advantage is to be faster than others. It was true for Paul Graham, still true now. A dynamic language made sense. A microservice architecture in the Go style would not be right at this stage.

If you were measuring "fast" in the Taylor + [], time-and-motion study sense, you would of course find that speed advantages accrue from smallest iteration you do most often. While coding, it comes down to how quickly can you change code and evaluate its reusult.

Go has a fast compile time so it actually does this quite well.

But in my experience, independent of compile time, I was spending a lot of time writing other code to hit the code I was developing, in a scenario with real data. 

Let me briefly explain my latest Go workflow: I would start with integraiton tests. I would try to spend as much time as possible coding while in the debugger, so I could look into values of my running program. I would restart restart the debugger often to nagivate to another breakpoint and inspect some more. At the very end, I would refactor into components as necessary, then bump up test coverage with unit tests. These I write with the help of ChatGPT.

Not bad and even quite productive. But looking back it was far from "flowy". integration tests were tricky to write. My test often blew up somewhere before hitting the code I was trying to debug. Or I had to think about compilation errors before my program could run again.

I was probably using Go wrong the whole time, trying to make the debugger into a REPL. My main goal early this year was to go as deep as possible into a real REPL, while re-learning how to do the things I could already do well in Go.

## How to learn a language

I had some fears. Clojure sucks on ChatGPT. Nicely written blog posts were often missing syntax highlighting, made the code seem impenetrable. Was is it even sane to go into a language without that support, at this stage in life?

Everyone learns a different way. My preferred way of learning is to get something working, even if I don't know the details of how it's working, and then discover more as I go. 

For instance, when I got my current SLR camera as a hand-me-down from my father in law, I started on auto mode. Slowly I discovered what the buttons were for. I am still mainly in auto mode; there are a lot of buttons.

Frameworks are great for this auto mode, and Go mostly lacked them. One of the things I wanted most in this switch was to find a good framework, at least for a while.

But Clojure, like Go, didn't come from a framework mentality, I thought. It didn't have a Rails.

First thing I learned is that.. yes it does. 

## Clojure has its own Rails

I'm talking about Biff. After some time with it, it seems to tick the boxes:

1. Very opinionated + fast to develop.
2. Made for the traditional Web stack, not SPA.
3. Useful tools, for example for starting a development server, deploying etc.

I haven't been around Rails for a while, so I'm sure it's missing a few things. But it has others besides, thanks to XTDB, malli and other libraries, that I know for a fact Rails doesn't have.

What Biff definitely provides is an auto mode. I was able to deploy a secure site on day one and get to work. (I'll get to prod-dev later.)

But an auto mode is only useful if you can turn it off. Last I recall, with Rails, that was not easy. Rails itself is 350,000 lines of code, and it has dozens of dependencies. It was not easy to drop down into ActiveRecord internals or the Arel gem to learn or change behavior.

Biff is 5,000 lines. It is 1.4% the size of Rails. 

So far, most of what I have produced is variants of Biff applications, with a bit added and a bit removed. The main way I have learned Clojure so far is to slowly read through all of those 5,000 lines of code, function by function, until I know how they work.

Here is a POC for using Keyclaok with Biff, for instance, instead of its included authentication module.

## It's not so emacsey anymore.

Calva. I was working with a data anlyst and he was able to use Calva to execute some Tablecloth "notebooks" (really Clojure namespaces.) 

Clojure gets attacked because it needs tooling. I would say Go is even more like this.

## Buid tools

In Biff, you can spin up your project and a REPL, or just a REPL by jackin in with Calva. Both are very useful.

The tools.deps arguments were hard to remember. I found the CLojure cheatsheet very useful. I haven't found a similar cheatsheet for the CLI, but it would be helpful.

Coming from Go, the deps system seems more full featured and more powerful. It would be amazing to see Babashka there. 

Neil was helpful to get projects going. My impression is that 

Java interop was tough at first.

## Reading code

This was my biggest misgiving. I have to say it was mostly unfounded. I can navigate c

I miss runnable examples from Go. There are often executable `comment` macros in Clojure code, but there is no standard for examples.
I saw an `^:example` meta tag somewhere, which seemed like a good idea.

The greatest strenght of Clojure is its executability. If there was a way to have a "try me" button at the function level, woudl be amazing. 

## Runtime

The Go runtime is very forgiving, and it's easy to do stuff in various threads etc.

Error handling in Go is simple but ugly. In Clojure, it's not simple at all. Have been looking at (lib). There are a couple of worrying issues there and lack of activity.




## Java interop

Deps was a real help here. I'm not a JI was able to compile Java libraries nad 

The first day was extremely frustratig. After I figured out I could open the class name in the Cider inspector to see a list of the methods, 

I still haven't been able to get cider-javadoc to work. 

## Data 

## Scripting

We were using Goluago to introduce some dynamic elemetns into a static JSON configuration. For example:

```
{
   ...
   "client_id": "{{ Secrets.get('clientId') }}"
}
```

This allowed us to have multitenant systems that responded to changing user requirements. The lua code in the brackets would be run in a sandboxed environment via the goluago library.  This worked fairly well. 

In Clojure, there's Sci. Transit, 

https://www.metosin.fi/blog/transforming-data-with-malli-and-meander

https://github.com/cognitect/transit-format

TODO figure this out

```
{
   "client_id": ""
}
```

## Double down on frameworks

- Form helpers. I 
