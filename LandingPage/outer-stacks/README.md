# The Shared Outer Stacks

An experimental, third-person ReEnchanted story world. Readers enter as Paperwings, meet without ordinary chat, and make meaning with movement, gesture, play, and words that have to be found, gathered, carried, and given.

## Wake the clearing

From the project root:

```sh
node scripts/outer-stacks-server.mjs
```

Then visit [http://127.0.0.1:50124/outer-stacks/](http://127.0.0.1:50124/outer-stacks/).

For two local identities in the same browser, use `?wing=one` and `?wing=two` in separate tabs.

## Controls

- Move with WASD, arrow keys, or by clicking the ground. Hold Shift to run.
- Hold Space or the Gather control near a loose word. The time and motion differ by the word's temperament.
- Press Q or Offer to place a carried word. Near the basin, the offering becomes part of the clearing's memory; elsewhere, another Paperwing may choose to gather it.
- Use the dock or number keys 1–4 for bodily gestures.

## What is shared

The small Node server synchronizes position, animation pose, gesture, carried words, loose words, chases, offerings, and the clearing's memory. It deliberately does not receive private Book Pages, personal memories, real names, account data, or location.

The clearing's accumulated offerings and chase paths are stored in `/private/tmp/reenchanted-outer-stacks-state.json`. Player identities and positions are temporary and disappear after inactivity.

## Asset notes

`assets/paperwing.glb` is a Blender-generated, rigged low-poly model with twelve clips: idle, walk, run, skid, crouch, sleep, hide, bow, beckon, call, offer, and refuse. Rebuild it with:

```sh
blender --background --python scripts/build_outer_stacks_paperwing.py -- --output LandingPage/outer-stacks/assets/paperwing.glb
```

The current avatar and environment are prototype art. Their purpose is to test embodiment, scale, gathering, expressive multiplayer, and world memory before committing to the final painterly model and animation language.

## Checks

```sh
node --test scripts/outer-stacks-server.test.mjs
node --check LandingPage/outer-stacks/outer-stacks.js
node --check scripts/outer-stacks-server.mjs
```
