# Lesson 1: Anatomy of Your Svelte App

*Understanding what every file does in your music-interval-training app*

---

## 1. What Is Svelte?

Svelte is a **compiler** for building user interfaces. Unlike React or Vue, which ship a runtime library to the browser and do work there, Svelte does its heavy lifting at **build time**. When you run `npm run build`, Svelte reads your `.svelte` files and compiles them into plain JavaScript that directly manipulates the browser's DOM (the page elements you see). [[svelte.dev](https://svelte.dev/docs/svelte/getting-started)]

This means:

- **No virtual DOM** -- Svelte generates code that updates exactly the parts of the page that changed, nothing more
- **Smaller bundles** -- there's no framework runtime shipped to the user's browser
- **Less boilerplate** -- a Svelte component is closer to plain HTML than most frameworks

> **Key Idea**
>
> React/Vue: your code + framework runtime are sent to the browser, and the framework interprets your components at runtime.
>
> Svelte: your code is compiled into optimized vanilla JS at build time. The browser gets just the result.

---

## 2. Svelte vs. SvelteKit

Your app uses **two things**, and it's important to know which is which:

- **Svelte** -- the component language. Each `.svelte` file is a component. Svelte handles how components look and behave. [[svelte.dev/docs](https://svelte.dev/docs)]
- **SvelteKit** -- the app framework built on top of Svelte. It handles routing (which URL shows which page), the dev server, building for production, and more. [[svelte.dev/docs/kit](https://svelte.dev/docs/kit/introduction)]

Think of it like this: Svelte is the **brick**, SvelteKit is the **house**. Svelte teaches you how to build individual UI pieces. SvelteKit tells you where to put them so they form a working web app.

---

## 3. Your App's File Structure

Here's what the important files and folders in your project do:

```
music-interval-training/
  package.json              -- lists dependencies and scripts (npm run dev, etc.)
  svelte.config.js          -- tells SvelteKit how to build (adapter, settings)
  vite.config.ts            -- config for Vite, the build tool that runs everything
  src/
    app.html                -- the HTML shell, wraps everything
    app.css                 -- global styles (just imports Tailwind)
    routes/                 -- PAGES! file structure = URL structure
      +layout.svelte        -- wraps every page (sets <title>, loads CSS)    <-- important
      +page.svelte          -- the main (and only) page of your app          <-- important
    lib/                    -- shared code, imported as $lib/...
      components/           -- reusable UI pieces
        Fretboard.svelte    -- the guitar fretboard at the bottom            <-- important
        InfoPanel.svelte    -- the reference table sidebar                   <-- important
      music/                -- music theory logic (intervals, chords, notes)
      audio/                -- sound playback (Web Audio, ABC notation)
      exercise/             -- question generation logic
      stats/                -- score tracking (localStorage)
      i18n/                 -- translations (English/Czech)
```

> **Try This**
>
> Open your project in a file explorer or your editor. Match each folder to the description above. The most important file for now is `src/routes/+page.svelte` -- that's where almost all of your app's UI lives.

---

## 4. The Three Sections of a .svelte File

Every `.svelte` file can have up to three sections. Think of it like a sandwich: [[svelte.dev](https://svelte.dev/docs)]

```svelte
// 1. SCRIPT -- the brain (JavaScript/TypeScript logic)
<script lang="ts">
  let count = 0;
</script>

<!-- 2. MARKUP -- the face (HTML that the user sees) -->
<button onclick={() => count++}>
  Clicked {count} times
</button>

<!-- 3. STYLE -- the clothes (CSS, scoped to this component) -->
<style>
  button { color: blue; }
</style>
```

All three are optional. Let's look at your actual files:

### Your +layout.svelte (the simplest possible example)

```svelte
// SCRIPT section
<script lang="ts">
  import '../app.css';          // loads Tailwind CSS globally
  let { children } = $props(); // receives the page content
</script>

<!-- MARKUP section -->
<svelte:head>
  <title>Interval Training</title>
</svelte:head>

{@render children()}    <!-- "put the page content here" -->
```

This layout wraps **every page**. It loads CSS, sets the browser tab title, and then renders whatever page you're on via `{@render children()}`. Since your app only has one page (`+page.svelte`), the layout wraps just that page.

### Your app.css (the shortest file)

```css
@import 'tailwindcss';
```

That's the entire file. It just activates Tailwind CSS, which is why all your styling uses classes like `bg-gray-950`, `text-white`, `flex`, etc. directly in the HTML markup.

---

## 5. How Routing Works

SvelteKit uses **file-based routing**. The folder structure inside `src/routes/` directly maps to URLs: [[svelte.dev/docs/kit/routing](https://svelte.dev/docs/kit/routing)]

```
src/routes/+page.svelte           -->  http://localhost:5173/
src/routes/about/+page.svelte     -->  http://localhost:5173/about
src/routes/settings/+page.svelte  -->  http://localhost:5173/settings
```

Your app has only one page -- `src/routes/+page.svelte` -- which maps to the root URL `/`. If you wanted to add a second page (say, an "about" page), you'd create `src/routes/about/+page.svelte`.

The `+layout.svelte` file wraps all pages in its directory. It's like a picture frame -- different pictures (pages) go inside, but the frame stays the same.

---

## 6. Components: Building Blocks

A component is a reusable piece of UI. Your app has two custom components:

- `Fretboard.svelte` -- the guitar fretboard at the bottom of the screen
- `InfoPanel.svelte` -- the reference table that slides in from the right

Components live in `src/lib/components/` and are used by importing them:

```svelte
// In +page.svelte, the SCRIPT section:
import Fretboard from '$lib/components/Fretboard.svelte';
import InfoPanel from '$lib/components/InfoPanel.svelte';

// Then in the MARKUP section, use them like HTML tags:
<Fretboard {highlights} {mutedStrings} {activeNoteMidi} />
<InfoPanel mode={exerciseType} />
```

> **TypeScript Note**
>
> You'll notice `<script lang="ts">` at the top of your files. This just means "I'm writing TypeScript instead of plain JavaScript." TypeScript adds **type annotations** -- labels that say what kind of data a variable holds. For example, `let count: number = 0` means "count is a number." If you see a colon followed by a type name, that's TypeScript -- you can mentally skip it for now and focus on the logic.

---

## 7. The $lib Shortcut

You'll see imports like `$lib/components/Fretboard.svelte` everywhere. The `$lib` is a SvelteKit shortcut that always points to `src/lib/`. It saves you from writing long relative paths like `../../lib/components/...`.

So when you see:

```ts
import { recordAnswer } from '$lib/stats/store';
```

It's loading from the file `src/lib/stats/store.ts`.

---

## 8. Where To Look When You Want To Change Something

Here's a practical cheat sheet for your app:

| I want to change...                      | Look in...                                       |
| ---------------------------------------- | ------------------------------------------------ |
| The page layout, buttons, exercise flow  | `src/routes/+page.svelte`                        |
| The fretboard display                    | `src/lib/components/Fretboard.svelte`            |
| The reference info panel                 | `src/lib/components/InfoPanel.svelte`             |
| What intervals/chords exist              | `src/lib/music/intervals.ts` or `chords.ts`      |
| How sounds are played                    | `src/lib/audio/engine.ts`                        |
| How scores are tracked                   | `src/lib/stats/store.ts`                         |
| Translations (English/Czech text)        | `src/lib/i18n/translations.ts`                   |
| The browser tab title                    | `src/routes/+layout.svelte`                      |
| Global styles / Tailwind config          | `src/app.css`                                    |

---

## 9. Quick Check

**1. If you wanted to add a new page at the URL `/settings`, where would you create the file?**

- a) `src/lib/settings/+page.svelte`
- b) `src/routes/settings/+page.svelte`
- c) `src/settings.svelte`

<details>
<summary>Show answer</summary>

**b) `src/routes/settings/+page.svelte`**

Pages go in `src/routes/`, and the folder name becomes the URL path.

</details>

---

**2. What does `$lib` in an import path refer to?**

- a) A special Svelte library installed via npm
- b) A shortcut to the `src/lib/` folder in your project
- c) The browser's local storage

<details>
<summary>Show answer</summary>

**b) A shortcut to the `src/lib/` folder in your project**

`$lib` is just a convenient alias for `src/lib/`.

</details>

---

**3. What are the three sections of a `.svelte` file?**

- a) HTML, CSS, JavaScript (in separate files)
- b) Script, Markup, Style (all in one file)
- c) Header, Body, Footer

<details>
<summary>Show answer</summary>

**b) Script, Markup, Style (all in one file)**

A `.svelte` file combines script (`<script>`), markup (HTML), and style (`<style>`) in a single file. All three are optional.

</details>

---

**4. What makes Svelte different from React?**

- a) Svelte uses a virtual DOM for faster updates
- b) Svelte runs entirely on the server
- c) Svelte compiles components to vanilla JS at build time -- no virtual DOM, no runtime framework

<details>
<summary>Show answer</summary>

**c) Svelte compiles components to vanilla JS at build time -- no virtual DOM, no runtime framework**

Svelte is a compiler. It transforms your `.svelte` files into optimized JavaScript at build time, so no framework runtime is shipped to the browser.

</details>

---

## 10. What's Next

Now you know the **shape** of your app -- where files live and what they do. The next lesson will dive into the **markup section** of `.svelte` files: how `{#if}`, `{#each}`, `{curly braces}`, and event handlers like `onclick` work in your actual app code.

> **Try This Before Next Session**
>
> 1. Run `npm run dev` in your music-interval-training folder and open the app in a browser
> 2. Open `src/routes/+page.svelte` in your editor
> 3. Find the line that says `Interval Training` (hint: it's not in +page.svelte) and change it to something else. Save and watch the browser tab title update.
> 4. Look at the "cheat sheet" table above and try to match 2-3 things you see in the browser to the files listed
