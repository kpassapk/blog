---
title: We are drowning in Google's magnanimity
date: 2023-11-14T20:00:00-05:00
---

I've had a sneaking suspicion for a whle that OKRs - as in Objectives and Key
Results - are in fact clever device deployed by Google [^1] to throw startups off
track.

[^1]: OKRs were developed at Intel, but I learned about them from Google Ventures, so I'll blame Google for evangelizing.

The appeal of OKRs is in their perceived simplicity: any problem large, or
small, organizational or technical, made solvable by careful setting of O's and
KR's.[^2]

[^2]: Just remember to cascade your KRs and figure out if you want 0.7 attainment or more. And never tak about outputs, only outcomes.

It never plays out as promised. A few cycles deep into OKRs will leave
startups wondering why they're so dumb they can't implement what seems like a
pretty simple system.

I think the reason is that OKRs add one or two more terms exactly where we need
them least. We already have a bunch of good terms to talk about problem solving
in this domain, after all: a _roadmap_ expresses the "what"; _agile_ is the
"how".

Stay cynical with me for a just a second longer. What if OKRs are in fact a subtle
and careful ploy to keep startups off balance? Always failing because they are
trying to do too much; always feeling bad they can't actually be like the big-G?
GG, Google, gotta hand it to you.

In reality of course OKRs are just fine. At least they're fine _for Google_. For
a company with its particular needs and structure, sure, it's a fine way to run
things.

For the rest of us, though, this well-intentioned subtle reinvention of goal
setting just creates confusion. It makes us abandon the right tools for the job.
It promises to help us think, but only provides us half-ideas without the
context that made them work in the first place.

Lately I've been feeling the exact same thing about Kubernetes.

I think it suffers from the same syndrome as OKRs: at best it's an earnest
solution that aims to be general-purpose and "first-principles", and takes some
getting used to; at worst it assumes problems only Google has.

Let's take a trip back to Stanford, 1999-ish, back to when Google was a scrappy
startup, to see what those problems were.

As any startup, Google had to figure out what kind of systems best suited its
business needs. But it also had some papers that kind of tied the room together.
It hired some of the best and brightest to flesh out this research-ey core in
gory detail and turn it into a product. Amazingly, it worked. Google managed to
keep the wolf at the door and search took off.

To succeed here, the company needed to achieve "embarrassingly parallel" by
networking a large number of machines.

Pretty soon the company figured out ads were the thing. Out came more shiny tech
and more white papers. Fast forward to Spanner, which handles all of this with
["no compromises"](https://cloud.google.com/spanner?hl=en). Custom-built
networking gear, atomic clocks, and masses of undersea fiber-optic cable work
together to loosen up the CAP theorem enough for the "no compromises" claim to
be made.

Now comes gmail, a Web app. Of course it runs on the same no-compromises,
heavily networked backend, because how else.

At this point in the story, Google is rich and feeling magnanimous. They can't
possibly keep all this good stuff just for themselves.

So one fine day, they graciously decide to take a good chunk of that accumulated
knowledge about being Google, distill it into an open source tool (soon
'ecosystem'), and release it upon an unsuspecting world. Borg-lite becomes
Kubernetes.

Yes, the name is weird, but it comes with convenient shorthand! Via `k8s` we can
`kubectl apply` our way to some lovely abstractions: Horizontal Pod Autoscalers!
Node Affinities! StatefulSets! NetworkPolicies! etc. Just being in the vicinity
of such new Terms makes us feel empowered, even if they are a [lot to learn][iceberg].

[iceberg]: https://asankov.dev/blog/2022/06/12/demystifying-the-kubernetes-iceberg-part-5/

Striving to be research-ey and practical at the same time, k8s evolves a huge
configuration area - only to paper it over with lots of YAML files. Every main
component in its 2.4M+ line codebase is extensible. (Sounds like "no
compromises", kinda.)

To think that we just talked about Web servers and a Databases back in the
day... oh we were so pure.

What we didn't have before, and we apparently have now, is this: armed with
these powerful concepts, we can scale up / operate like Google!

Except we can't.

Because you know who's really good at finding their way out of this rats nest of
YAML? Google is. Nobody else seems to be particularly good at it. We've been
shifted-left to, hard. And it sucks.

Whereas before we had perfectly good tools to solve problems for our customers,
now we need an advanced degree just to figure out our new machinery - which, we
are told, resolves all earlier problems, but from first principles. (We were too
busy being pragmatic to see it!) 

It's the OKR problem all over again, only this time without even the veneer of
simplicity.

Startups don't need to spend time decyphering k8s any more than they need to be
thinking about designing their own networking chips, installing atomic clocks,
or laying undersea cables.

No doubt the same compulsion to keep giving shit away will soon provide startups
with more ways to fail at being Google. Time to put a stop to it.

We are drowning in a sea of Google's magnanimity, and it's sure going to be hard
to find our way out.

Stay tuned for "We are drowning in Facebook's magnanimity" :)
