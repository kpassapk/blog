---
title: Implementing stateful workflows with the Temporal Clojure SDK
date: 2023-08-13T19:30:00-05:00
---

Sometimes you have long-running processes that must be completed in several
steps, with dependencies on external systems (microservices or external APIs.)

Examples are:

- Application collects a lot of input from the user, like when creating an AirBnB listing
- A process like an airline booking, with fare calcualtion, seat selection ,etc.
- A bidding tool where you are collecting bids from many parties on external devices, 
 collectin the results.
- A long-running ETL processes, where you want to ensure observability and pick up
  where you left off
- Reverse ETL, where you have a lot of information to push out to an external
  system, and should slow down to a rate limit.

The typical solution to these problems involves a lot of message queues, databases and key/value stores. This creates a few problems.

First, Lots of code. It will be hard to see the flow of operations "at a glance", since many modules will have a slice of it.

- You lose readability of the system you are building. Integration tests are perhaps the only place where the sequence of operations is visible. 

- You end up with state-related concepts in the data model that are not part of your domain logic, but which are necessary for the game to run.

- You will probably need to build UIs to see at a glance which of your long-running processes are "in flight", which have been completed, and which have errors.

# The goal

In this exmaple, we will create a stateful greeter that can deliver three steps.

It will have a timeotu of 30 seconds from the moment in which the greeter was started.

# Traditional approach

To implement this, we could use a database and add a table for greeter state.

If we used a key/value store, we could also store a server-side session to represent  state.

To handle the five minute timeout, we could check before each move if the  is still alive, adding 

We could set a timer. If our program has many instances running in a server, and 

# Temporal

Temporal is a workflow orchestration tool. 

We use the [Temporal SDK][sdk] for Clojure. 

[sdk]: https://github.com/manetu/temporal-clojure-sdk/

We define a greeter activity

```clojure
(defactivity greet-activity
  [ctx {:keys [name] :as args}]
  (str "Hi, " name))
```

We can call this activity from the REPL

(comment
  (greet-activity nil {:name "Kyle"}) ;=> "Hi, Kyle"
  )
  
We define a stateful greeter workflow, which can deliver up to three greetings by calling the activity above. 
It starts with a state atom set to zero, and then when it receives the "greet" signal, it invokes the greet 
activity above.

We send the resulting greeting using the `::greeting` signal. If this syntax is unfamiliar, this is a fully 
qualified symbol.



```clojure
(defworkflow greeter-stateful-workflow
  [args]
  (let [max-greetings 3
        state (atom 0)]

    (s/register-signal-handler!
     (fn [signal-name {:keys [workflow-id] :as args}]

       (when (= (keyword signal-name) ::greet)
         (>! workflow-id ::greeting @(a/invoke greet-activity args))

         (tap> @state)

         (swap! state inc))))

    (w/await
     (fn []
       (>= @state max-greetings)))
    @state))
```

The greeting workflow is called once per greeting. It will call the stateful greeter with the ::greet
signal, and then wait for the ::greeting signal.

```clojure
(defworkflow greeting-workflow
  [{:keys [greeter-workflow-id name]}]
  (let [signals (s/create-signal-chan)
        {:keys [workflow-id]} (w/get-info)]
    (>! greeter-workflow-id ::greet {:workflow-id workflow-id :name name})
    (<! signals ::greeting)))
```

