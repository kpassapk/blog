---
title: Extensibility at the edge of the system
date: 2023-11-14T20:00:00-05:00
draft: true
---

At some point in writing an enterprise applicaiton, you have to decide if behavior is configured or coded.

https://mikehadlow.blogspot.com/2012/05/configuration-complexity-clock.html

Something not met by either configuration or code
- Configuraiton was not enough to express the behavior
- Code is too hard to read by non-coders

We can go full-cde and introduce a "business readable DSL"
https://martinfowler.com/bliki/BusinessReadableDSL.html

We want to keep the configurations compact, thoug. How to do 6pm before it becomes Greenspun's Tenth Rule?

"Any sufficiently complicated [...] program contains an ad hoc, informally-specified, bug-ridden, slow implementation of half of Common Lisp."

Soft-deletion. Tweaks to a validation model - things like `AllowNegativeQuantities`, is another. Creeping up on business rules.

Authorization. 



https://martinfowler.com/bliki/RulesEngine.html

A workflow in AWS; invoke a Lambda function as an action. Rules engine.

Greenspun's rule suggests using a widely accepted, fully featured language like Lisp. Like Lisp? 

I'm a huge fan, but there's a better alternative: use 

There's a better 6pm - 9pm: use a language that's close in semantics to what 

Configuration clock

Blur the lines between configuration and code.

Lua as an "extensible extension program"


I'm a huge fan, but it might be  abit of a stretch if your main codebase is in Go.

https://martinfowler.com/bliki/BusinessReadableDSL.html


## Lua

Lua similar design goals as Go
- minimal syntax
- simplicity, portability

Lua has similar semantics to go
- nil 
- multiple return values
- first class functions

Also a single powerful data type: a table.


## Stack-based 


## libraries

https://github.com/Shopify/goluago

## parag1 

Editors have used this for a while. 
