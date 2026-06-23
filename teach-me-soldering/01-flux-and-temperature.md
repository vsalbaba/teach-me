# Lesson 1: What Flux Does and Why Temperature Matters

*The two things that separate bad joints from good ones*

**Contents**
1. [Why Your Joints Come Out Bad](#1-why-your-joints-come-out-bad)
2. [The Invisible Enemy: Metal Oxide](#2-the-invisible-enemy-metal-oxide)
3. [What Flux Actually Does](#3-what-flux-actually-does)
4. [Your Flux: NC-223-ASM](#4-your-flux-nc-223-asm)
5. [Wait -- Doesn't Solder Wire Already Have Flux?](#5-wait----doesnt-solder-wire-already-have-flux)
6. [When to Add Extra Flux Paste](#6-when-to-add-extra-flux-paste)
7. [Temperature: The Other Half](#7-temperature-the-other-half)
8. [Setting Up Your Pinecil V2](#8-setting-up-your-pinecil-v2)
9. [Check Your Understanding](#9-check-your-understanding)

## 1. Why Your Joints Come Out Bad

Most bad solder joints have the same two root causes:

1. **Wrong temperature** -- too cold and the solder won't wet; too hot and the flux burns off before it can work
2. **No flux on the joint** -- or the flux in the solder wire was consumed before the joint was ready

With an uncontrolled transformer iron, you had no way to fix problem #1. The Pinecil V2 solves that. This lesson tackles both.

## 2. The Invisible Enemy: Metal Oxide

Every metal surface exposed to air grows a thin layer of **oxide**. You can't see it, but it's there -- on your ESP32 header pins, on the PCB pads, on your solder wire, and on your iron tip.

> **Oxide is the reason solder doesn't stick.** Molten solder bonds to clean metal through a process called *wetting*. Oxide blocks wetting. It's like trying to glue two surfaces with dust between them -- the glue touches the dust, not the surface.
>
> *Source: [Chemtronics -- Essential Guide to Flux](https://www.chemtronics.com/essential-guide-to-flux-for-soldering-electronics)*

This is why a joint can look like the solder just *sits on top* instead of flowing around the pin. The solder melted, but it couldn't wet the oxidized metal underneath.

## 3. What Flux Actually Does

Flux is a chemical that does three things, in order, when heated:

1. **Dissolves oxide.** The acids in flux (weak organic acids derived from pine rosin) chemically react with metal oxide and break it apart.
2. **Shields from air.** The melted flux coats the hot metal surface, preventing new oxide from forming during the seconds you're soldering.
3. **Reduces surface tension.** This lets the molten solder *flow* and *wet* the clean metal instead of balling up.

Without flux, the solder can't bond to the metal. With flux, it flows into every crevice and forms a solid metallurgical joint.

```
  Before flux:                    After flux:

  Solder blob                     Solder fillet
       ___                            .
      /   \                          /|\
     |     |     oxide layer        / | \
  ===.=====.===  ~~~~~~~~~~~~    ==.==|==.==
  ~~~~PCB pad~~  blocks flow     ~~PCB pad~~
                                 clean metal, solder wets
```

*Source: [Chemtronics](https://www.chemtronics.com/essential-guide-to-flux-for-soldering-electronics), [ElectronicsHub](https://www.electronicshub.org/how-to-use-solder-flux/)*

## 4. Your Flux: NC-223-ASM

The NC-223-ASM is a **no-clean flux paste** in a syringe. Here's what that means for you:

- **No-clean** -- the residue left behind is non-conductive and non-corrosive. You can leave it on the board. (You can clean it with isopropyl alcohol if you want it to look neat, but you don't *have* to.)
- **Paste format** -- thick, sticky, stays where you put it. Apply with a toothpick or the syringe tip directly.
- **BGA-grade** -- it's designed for fine-pitch BGA rework, which means it's more than strong enough for through-hole ESP32 headers. You have good flux -- don't be afraid to use it.

> **Safety -- Fumes:** When flux heats up, it produces fumes (mostly rosin/colophony smoke). These can cause respiratory irritation over time. In your apartment:
>
> - Open a window near your workspace
> - Point a small desk fan to blow fumes away from your face (not at you)
> - Better: build a [$20 DIY fume extractor](https://oscarliang.com/diy-solder-smoke-extractor/) with a PC fan + activated carbon filter
> - Don't solder in a closed room with no airflow

## 5. Wait -- Doesn't Solder Wire Already Have Flux?

Yes. Your tin solder wire almost certainly has a **rosin core** -- flux built into the center of the wire. When the wire melts, the flux releases automatically.

For many simple through-hole joints (one pin, one pad, clean surfaces), the core flux is enough. You heat the pad and pin, touch the solder wire, and the core flux cleans the surface as the solder melts.

> **So why do you also need flux paste?** Because the core flux is a small, fixed amount. It runs out fast. If the joint takes more than ~2 seconds, or the surfaces are oxidized, or you're doing multiple pins in sequence, the core flux burns off and you're back to soldering on oxide.
>
> *Source: [Chemtronics](https://www.chemtronics.com/essential-guide-to-flux-for-soldering-electronics)*

## 6. When to Add Extra Flux Paste

Use your NC-223-ASM flux paste in these situations:

1. **Multi-pin headers** (like ESP32 headers) -- you're soldering 15+ pins in a row. By pin 5, the board is hot and flux is depleting. Pre-apply flux along the whole row.
2. **Fixing a bad joint** -- reheating an old joint. The original flux is gone, the surface has re-oxidized. Fresh flux is essential.
3. **Solder bridges** -- if two pins are bridged, add flux and drag the iron tip between them. The flux helps the solder flow to the pins instead of bridging.
4. **Oxidized parts** -- old components, tarnished pads, or wire that's been sitting around.
5. **Tinning wire ends** -- stranded wire or component leads benefit from flux before tinning.

> **Try this -- Look at your solder wire.** Is there text printed on it? Look for two things:
>
> - The **alloy**: Sn60/Pb40 or Sn63/Pb37 means leaded. SAC305 or Sn99.3/Cu0.7 means lead-free.
> - The **diameter**: 0.8mm is ideal for ESP32 work. 1.0mm is fine. Thicker is harder to control.
>
> Check this now -- the alloy determines what temperature to set.

## 7. Temperature: The Other Half

Flux and temperature work together. Here's why:

| Too cold | Too hot |
|---|---|
| Solder melts slowly or not at all | Flux burns off instantly (smoke puff) |
| You hold the iron longer, burning flux | Solder flows before flux can clean |
| Joint looks dull and lumpy (cold joint) | Tip oxidizes fast, stops transferring heat |
| You press harder (bends pins, lifts pads) | Risk of pad delamination on cheap PCBs |

**Right temperature:**
- Flux activates and cleans the surface (~1 second)
- Solder melts and wets the joint smoothly (~1-2 seconds)
- Total contact time: 2-3 seconds per joint
- Joint looks shiny (leaded) or slightly satiny (lead-free), concave, smooth

> **The rule of thumb:** Melting point of your solder + 120C = working temperature. Then adjust +/- 10C based on results. Start lower, go up 5C at a time.
>
> *Source: [PINE64 Wiki](https://wiki.pine64.org/wiki/Pinecil_Guides_to_Soldering)*

## 8. Setting Up Your Pinecil V2

Starting temperatures -- adjust from here based on your solder alloy:

| Solder type | Temperature | Melting point |
|---|---|---|
| **Leaded** (Sn63/Pb37) | **320 C** | ~183C |
| **Lead-free** (SAC305) | **350 C** | ~217C |

### Before you solder: the setup checklist

1. **Power supply:** Use a USB-C PD charger rated 65W / 20V / 3A or higher. A phone charger won't deliver enough power. ([PINE64 Wiki](https://wiki.pine64.org/wiki/Pinecil))
2. **Set temperature:** Use the buttons on the Pinecil. Start at the values above.
3. **Tin your tip:** When the iron is hot, melt a small blob of solder onto the tip. Wipe on a damp sponge or brass wool. The tip should look shiny silver, not grey or black.
4. **If the tip looks dark and solder won't stick to it:** The tip is oxidized. Apply flux paste to the tip, then add solder. The flux will clean the oxide and the solder will tin the tip again.

> **Try this -- Test your setup now.** Plug in your Pinecil, set it to 320C (or 350C for lead-free), and practice tinning the tip. Melt a tiny bit of solder on it, wipe on a sponge, repeat. The tip should be shiny after wiping. If it won't tin, add flux paste to the tip first, then solder.

## 9. Check Your Understanding

**Q1: What does flux remove from metal surfaces?**

<details>
<summary>Show answer</summary>

**Metal oxide.** Flux dissolves the invisible metal oxide layer that forms when metal is exposed to air. This oxide is what prevents solder from wetting (bonding to) the surface. Flux does not remove dirt, old solder, or moisture -- those are separate problems.

</details>

---

**Q2: Your NC-223-ASM is a no-clean flux. What does that mean?**

<details>
<summary>Show answer</summary>

**The residue is safe to leave on the board.** No-clean flux *does* leave residue, but that residue is non-conductive and non-corrosive. You *can* clean it with isopropyl alcohol for aesthetics, but you don't have to. It does not mean "no residue" or "self-cleaning."

</details>

---

**Q3: You're soldering an ESP32 header (20 pins). When should you apply flux paste?**

<details>
<summary>Show answer</summary>

**Before you start -- along the whole row of pads.** With 20 pins, the rosin core in your solder wire won't provide enough flux for the entire row. By pin 5, the board is hot and the core flux is depleting. Pre-applying paste along the pads gives every joint fresh flux.

</details>

---

**Q4: What happens if your iron temperature is too high?**

<details>
<summary>Show answer</summary>

**The flux burns off before it can clean the surface.** You'll see a quick puff of smoke as soon as the iron touches down, and the solder won't wet properly because the oxide layer wasn't cleaned. Excessive heat also oxidizes the tip faster and risks delaminating pads on cheap PCBs.

</details>

---

**Q5: Your Pinecil tip looks dark/grey and solder balls up on it instead of coating it. What do you do?**

<details>
<summary>Show answer</summary>

**Apply flux paste to the tip, then add solder.** The tip is oxidized -- the same problem flux solves on PCB pads. The flux will dissolve the oxide and then solder can wet and re-tin the tip surface. Never file or sand a tip -- it destroys the protective iron plating.

</details>
