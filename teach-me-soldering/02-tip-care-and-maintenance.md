# Lesson 2: Why Your Tip Stops Working (and How to Fix It)

*The care habits that keep solder flowing -- and how to rescue a dead tip*

## Contents

1. [What's actually happening when solder beads off](#1-whats-actually-happening)
2. [What's inside your tip (and why it matters)](#2-whats-inside-your-tip)
3. [How oxidation kills your tip -- slowly](#3-how-oxidation-kills-your-tip)
4. [The four habits that prevent it](#4-the-four-habits-that-prevent-it)
5. [Rescuing an oxidized tip (escalation ladder)](#5-rescuing-an-oxidized-tip)
6. [What to NEVER do](#6-what-to-never-do)
7. [When to give up and replace](#7-when-to-give-up-and-replace)
8. [Pinecil V2 specifics](#8-pinecil-v2-specifics)

---

## 1. What's Actually Happening

You described the problem perfectly: the tip stops "attracting" solder, and it beads up and rolls off. In Lesson 1, you learned that **oxide blocks wetting** on PCB pads. The exact same thing happens to your tip.

> **Your tip is a heat-transfer tool.** Its only job is to conduct heat from the heating element to the joint. When the tip is coated in a thin layer of solder (tinned), it transfers heat efficiently -- the molten solder on the tip makes direct metal-to-metal contact with the workpiece. When the tip is oxidized, the oxide layer acts as a thermal insulator. Heat can't get through. Solder can't wet. Everything fails.
>
> *Source: [Hakko -- Keeping the Tip in Good Condition](https://www.hakko.com/english/support/maintenance/detail.php?seq=183)*

This is why an oxidized tip feels like it "stopped heating up" even though the temperature readout hasn't changed. The element is hot, but the oxide is blocking the heat from reaching the solder.

## 2. What's Inside Your Tip

Understanding tip construction explains why certain things kill tips and others don't.

```
Cross-section of a soldering tip:

┌─────────────────────────────┐
│  Iron plating (working      │ <-- Thin protective layer
│  surface you solder with)   │     Wets with solder
│  ┌───────────────────────┐  │     Oxidizes over time
│  │                       │  │
│  │   Copper core         │  │ <-- Excellent heat conductor
│  │   (bulk of the tip)   │  │     Dissolves into solder
│  │                       │  │     if exposed
│  └───────────────────────┘  │
└─────────────────────────────┘
```

The **copper core** conducts heat from the heating element to the tip surface. The **iron plating** protects the copper from dissolving into the solder (copper is highly soluble in molten tin). The iron layer is thin -- typically 30-50 microns.

> **The iron plating is the tip's lifespan.** Once the iron is gone (from wear, corrosion, or physical damage), the copper underneath dissolves into solder, creating pits and holes. No amount of tinning or flux can fix a tip with compromised plating.
>
> *Sources: [iFixit](https://www.ifixit.com/Guide/How+to+Clean+and+Tin+a+Soldering+Iron+Tip/175931), [Metcal](https://www.metcal.com/solder-tips/how-to-remove-oxidation-from-your-solder-tips/)*

## 3. How Oxidation Kills Your Tip

Oxidation is a chemical reaction: iron + oxygen = iron oxide. It happens at room temperature (slowly) and at soldering temperatures (fast). Here's how it progresses:

1. **Healthy** -- Tip is tinned. A thin solder coat covers the iron. Solder wets easily. Heat transfers efficiently. The solder layer seals the iron from air.
2. **Exposed** -- Solder coat burns off or is wiped away. The bare iron is now exposed to air at 300+C. Oxide starts forming immediately -- you have seconds, not minutes.
3. **Oxidizing** -- Oxide layer grows. The tip darkens. Solder starts to bead instead of coating. You can still fix this easily with flux and fresh solder.
4. **Severely oxidized** -- Thick oxide layer. Tip is dark grey or black. Solder balls up completely and rolls off. Normal tinning doesn't work -- the oxide is too thick for rosin-core flux to cut through. You need chemical tip tinner.
5. **Damaged** -- Iron plating compromised. Pits, holes, or cracks in the plating. Copper is dissolving. The tip is dying. Replace it.

*Sources: [Metcal](https://www.metcal.com/solder-tips/how-to-remove-oxidation-from-your-solder-tips/), [Hakko](https://www.hakko.com/english/support/maintenance/detail.php?seq=183)*

> **Temperature is the accelerator.** Oxidation at 400C happens roughly twice as fast as at 350C. Your old transformer iron had no temperature control -- it may have been running at 450C+ and cooking the tips into oblivion while you worked. The Pinecil V2's temperature control is your biggest weapon against this.
>
> *Source: [Hakko -- How to Maximize Tip Life](https://kb.hakkousa.com/Knowledgebase/10322/How-to-Maximize-Soldering-Iron-Tip-Life)*

## 4. The Four Habits That Prevent It

Tip care is not a repair procedure. It's a set of habits you build into every soldering session.

### Start of session
**Heat up, then clean, then tin.** Power on the Pinecil. Wait for it to reach temperature. Wipe the old solder off on brass wool. Immediately melt fresh solder onto the tip. The tip should look shiny silver. Now you're ready to solder.

### During work
**Clean before each joint, not after.** This is the habit most people get backwards. Clean the tip on brass wool, then immediately make the joint. Don't clean and then set the iron down -- that leaves a bare tip exposed to air. If you're pausing between joints, leave the solder on the tip.

*Source: [Hakko -- "Clean the tip before soldering. If you clean it after, tip oxidation will accelerate."](https://www.hakko.com/english/support/maintenance/detail.php?seq=183)*

### Pausing (in holder)
**Leave solder on the tip.** When the iron sits in the holder between joints, the solder coat protects the iron from air. If it looks like the solder has burned off, add more before you set it down. If you're pausing for more than 5 minutes, turn the iron off entirely.

### End of session
**Tin generously, then power off.** Before you turn off the iron, melt a generous blob of solder onto the entire working surface of the tip -- not just the very point, but the sides too. This blob will solidify and seal the tip from air while it's stored.

*Sources: [iFixit](https://www.ifixit.com/Guide/How+to+Clean+and+Tin+a+Soldering+Iron+Tip/175931), [Stellar Technical](https://stellartechnical.com/blogs/electronic-assembly-technical-resources/the-importance-of-re-tinning-your-soldering-iron-tips)*

## 5. Rescuing an Oxidized Tip

Start at Level 1 and move up only if the previous step doesn't work.

### Level 1: Flux + fresh solder (mild oxidation)
Set the Pinecil to ~300C. Apply NC-223-ASM flux paste directly to the tip. Immediately melt solder onto the fluxed surface. Wipe on brass wool. Repeat if needed.

*Source: [Metcal](https://www.metcal.com/solder-tips/how-to-remove-oxidation-from-your-solder-tips/)*

### Level 2: Tip tinner / chemical paste (moderate-to-severe)
Heat the iron to working temperature. Press the tip into the tin of chemical paste and rotate slowly for 3-4 seconds. Wipe off residue on brass wool, then apply fresh solder. **Use sparingly** -- no more than every 20-30 sessions.

*Sources: [iFixit](https://www.ifixit.com/Guide/How+to+Clean+and+Tin+a+Soldering+Iron+Tip/175931), [Q Source](https://www.qsource.com/blog/481/how-to-use-tip-tinner-6-easy-steps-q-source)*

### Level 3: Brass brush + tip tinner (very stubborn)
Gently brush the hot tip with a brass wire brush to mechanically break up thick oxide, then immediately apply tip tinner. Do not press hard. Do not use steel brushes.

### Level 4: Replace the tip
If none of the above works, or you see pits, holes, or copper-colored spots, the iron plating is compromised. Replace the tip.

*Source: [PINE64 Wiki -- Pinecil Tips](https://wiki.pine64.org/wiki/Pinecil_Tips)*

## 6. What to NEVER Do

- **Never use sandpaper, files, or abrasive pads** -- strips the iron plating permanently
- **Never bang the tip against the bench** -- can crack the plating
- **Never leave the iron on and idle at working temperature** for extended periods
- **Never clean the tip and then put it down** -- tin immediately after cleaning
- **Never leave the tip clean for storage** -- always coat with solder before powering down

## 7. When to Give Up and Replace

**Replace if you see:** pits, holes, copper color showing through, cracks, deformed tip, or solder still won't wet after tip tinner.

**Salvageable if you see:** dark discoloration, black residue on the shaft, surface looks uniform but won't tin, no physical damage.

## 8. Pinecil V2 Specifics

- **Sleep mode**: Motion-based auto-sleep reduces temperature when idle. Make sure it's enabled.
- **New tip setup**: Wipe contacts with IPA, heat to 350C, tin, wipe on brass wool, repeat.
- **Tip swapping**: Always unplug before changing tips (V2 auto-detects resistance at boot).
- **Short tips**: Pine64 ST-B2 tips need at least 65W USB-C PD at 20V.

*Sources: [PINE64 Wiki -- Pinecil Tips](https://wiki.pine64.org/wiki/Pinecil_Tips), [PINE64 Wiki -- Guides to Soldering](https://wiki.pine64.org/wiki/Pinecil_Guides_to_Soldering)*
