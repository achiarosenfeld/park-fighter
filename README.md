# Park Fighter

A pixel-art brawler lives on top of your screen. He walks around at random, climbs onto the
tops of your open windows, rides them when you drag them — and every so often he picks a fight
with one: taunts it, punches it until it rattles, kicks it across the desk, then stomps it
closed or minimised and celebrates.

In between he does other things: wheels out an office chair and rolls across the screen on it,
throws up on the floor, does push-ups, takes a coffee break, sits down and scrolls his phone,
throws a hadouken (the fireball crosses the screen and rattles whatever it hits), and yells
things like **אני סתום** in a speech balloon. Leave the mouse alone for two minutes and he
falls asleep where he stands; move it and he wakes with a start.

He is drawn, not sprited: every frame is vector paths rendered fresh with Core Graphics in the
reference's cel-shaded style — flat colour, one offset shadow, bold black silhouette. Everything
below the neck is a skeleton posed in code, so the walk, punch, kick, stomp, taunt, victory,
stagger, dance and sit are all animated rather than pre-drawn frames.

The head is a cutout. `Resources/head.png` is lifted from the reference sheet (a real photo
works too — `head-photo.png` is one) and hung on the neck, tucked behind the collar, tilted
with the pose. Make a new one from any picture with a face in it:

```
.build/release/ParkFighter --cut-head photo.jpg Resources/head.png        # a photograph
.build/release/ParkFighter --cut-head sheet.jpg Resources/head.png 0      # frame 0 of a sprite sheet
```

Photos are masked with Vision's person segmentation; illustrations on a checkerboard are keyed
by flooding the backdrop from the edges, which the black ink around the figure stops. Turn the
cutout off in the menu ("Use his real head") to get the hand-drawn head in `Head.swift`.

## Build and run

```
./build.sh --run
```

That produces `build/ParkFighter.app` and launches it. There is no window — look for the 🥊 in
the menu bar.

To hand it to somebody else:

```
./package.sh
```

That compiles arm64 and x86_64, merges them into a universal binary, ad-hoc signs the app, and
writes `dist/Park Fighter.dmg` — a drag-to-install image holding the app, an Applications
symlink and the read-me — plus `dist/ParkFighter-mac.zip` for anyone who prefers a zip. Since
it is not signed with a paid Apple certificate, the first launch is blocked; the read-me inside
the image explains the Open Anyway steps.

## Menu

| Item | What it does |
| --- | --- |
| Pick a fight right now | Starts a beatdown on whatever window he is standing on or in front of |
| Taunt | "Come at me" |
| Do something stupid | Chair, yelling, vomiting, push-ups, coffee, phone or a fireball, at random |
| Use his real head | The cutout head instead of the hand-drawn one |
| Beat up my windows | Punching, kicking and shoving other apps' windows (on) |
| Let him close windows | Adds the closing and minimising finishers (on) |
| Nap time | He sits down and leaves everything alone |
| Size | Small / Normal / Large / Huge (Normal by default, about 160pt tall) |

## Accessibility permission

Rattling, shoving, minimising and closing windows all go through the Accessibility API, so macOS
asks for permission the first time he throws a punch. Until you grant it he shadow-boxes and
nothing moves. System Settings → Privacy & Security → Accessibility → allow **ParkFighter**.
Re-building the app changes its signature, so macOS may ask again — remove the old entry and
re-add it if it stops working.

Closing goes through the window's own red close button, so apps still get to ask you about
unsaved work. If that is still too much, turn off "Let him close windows".

## Flags

| Flag | |
| --- | --- |
| `--safe` | He mimes every prank; nothing outside the overlay is touched |
| `--log` | State transitions and prank effects to stderr |
| `--snapshot out.png` | Contact sheet of every animation frame (this is how the art is checked) |
| `--bench` | Times 300 frames of the renderer |
| `--faces out.png` | Just the six drawn faces, big |
| `--cut-head in out [index]` | Cuts a head out of a photo or sheet frame for `Resources/head.png` |
| `--head path.png` | Run with a different cutout without rebuilding |
| `--dump-windows` | Prints the windows found and the platforms they produce |
| `--render-icon out.png 256` | Draws the app icon |

## Layout

| File | |
| --- | --- |
| `Art.swift` | Palette plus the primitives: cel fill, ink outline, merged groups, tapered limbs |
| `Head.swift` | The hand-drawn face, curve by curve, with its six expressions |
| `HeadPhoto.swift` | Loads the cutout head; `--cut-head` builds one with Vision |
| `Body.swift` | Tee, sleeves, arms, fists, jeans, trainers, chair, mug, phone, fireball, vomit |
| `FighterArt.swift` | Draw order and the per-frame bitmap |
| `Poses.swift` | The skeleton and one function per animation |
| `Fighter.swift` | Brain and physics: walking, leaping, platform riding, beatdown choreography |
| `Pranks.swift` | The Accessibility layer: shake, shove, minimise, close |
| `WindowScanner.swift` | On-screen windows and the visible window-top segments he stands on |
| `App.swift` | Click-through overlay window, speech balloon, frame loop, menu bar |

Nothing is stored or sent anywhere. He reads window positions, draws on screen, and moves
windows when you let him.
