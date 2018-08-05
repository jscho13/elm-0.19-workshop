<i>This workshop is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/4.0/">Creative Commons Attribution 4.0 International License</a>. The `server/` directories use [`moleculer-node-realworld-example`](https://github.com/gothinkster/moleculer-node-realworld-example-app), which has its own license. The rest of the code is a variation on [`elm-spa-example`](https://github.com/rtfeldman/elm-spa-example/), an [MIT-licensed](https://github.com/rtfeldman/elm-spa-example/blob/master/LICENSE) implementation of the [`realworld`](https://github.com/gothinkster/realworld) front-end. Many thanks to the authors of these projects!</i>

Getting Started
===============

1. Install [Node.js](http://nodejs.org) 7.0.0 or higher

2. Clone this repository

Run this at the terminal:

```shell
git clone https://github.com/rtfeldman/elm-0.19-workshop.git
cd elm-0.19-workshop
```

3. Continue with either the [`intro`](https://github.com/rtfeldman/elm-0.19-workshop/blob/master/intro/README.md) or [`advanced`](https://github.com/rtfeldman/elm-0.19-workshop/blob/master/advanced/README.md) instructions, depending on which workshop you're doing!

===============
You can pattern match in elm:
type Length units = Length Float unit
you can pattern match on it..
add : Length units
add (Length num1 unit)

Now `num1` and `unit` are variables

With Phantom Types you don't even have to define it...
add : Length units
add (Length num1)

Totally valid. Notice how `unit` isn't even defined anymore


Sometimes when you try to make your code more optimized, it becomes less nice

