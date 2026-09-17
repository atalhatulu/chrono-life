# ChronoLife --- Master Game Design & Technical Architecture Plan

**Document Version:** 0.2 Freeze Candidate\
**Purpose:** This document consolidates the complete design discussion,
architectural decisions, critiques, revisions, MVP boundaries, and
implementation direction for ChronoLife. It is intended to be handed
directly to a coding agent (Codex/Astra/etc.) as the authoritative
project context before implementation begins.

------------------------------------------------------------------------

## 0. Instructions to the Implementing Agent

Do **not** treat this document as a request to immediately build the
full game.

The project must be developed incrementally. The first implementation
target is **Phase 0: Headless Simulation Kernel**.

Before changing architecture:

1.  Read this entire document.
2.  Preserve the core design philosophy.
3.  Do not add large systems merely because they seem useful.
4.  Prefer deterministic, data-driven, testable simulation.
5.  Do not build UI before the simulation kernel is demonstrably
    functional.
6.  Do not hard-code historical concepts into universal simulation
    systems where they can be represented as data/rules.
7.  Avoid scene-node-heavy architecture for simulation entities in
    Godot. Simulation should primarily be plain
    data/services/resources/ref-counted objects where appropriate.
8.  Every important state mutation must be explainable and traceable.
9.  Do not implement Dynasty, runtime LLM generation, cross-era
    transitions, mental-health simulation, or a mod API during Phase 0.
10. At the end of each implementation task, produce a technical report
    describing files changed, tests performed, unresolved issues, and
    sample simulation output.

Target engine/environment:

-   Godot 4.7.1
-   GDScript
-   Linux development environment
-   Initial game mode is text/UI-oriented, but Phase 0 is headless.

------------------------------------------------------------------------

# 1. High Concept

**ChronoLife** is a historical individual-life simulator.

The player controls **one human being**, from birth until death, while
living inside a historically constrained world.

The player does **not** control:

-   a country,
-   a city,
-   an army,
-   a dynasty,
-   a civilization.

The player controls a single life.

Core fantasy:

> "What would my life have been like if I had been born into a poor
> family in Manchester in 1850?"

Later examples could include:

-   a medieval peasant,
-   a Roman slave,
-   a Renaissance artisan,
-   a 19th-century industrial worker,
-   a person born before a world war,
-   a modern citizen.

The important distinction is that history is not decorative flavor.
Historical circumstances directly constrain the player's opportunities,
risks, rights, health, work, education, relationships, wealth, and
survival.

------------------------------------------------------------------------

# 2. Core Identity

ChronoLife must not become merely "BitLife with historical text."

The game should be differentiated by a real underlying simulation.

The key v0.2 paradigm is:

> **Life is produced by state changes and causal consequences. Storylets
> expose that simulated life to the player in a readable and interactive
> form.**

Storylets do not create the entire life.

The simulation creates conditions.

The Consequence Engine propagates those conditions.

Storylets turn relevant moments into player-facing decisions and
narratives.

------------------------------------------------------------------------

# 3. Design Pillars

## 3.1 Human-Centered History

Macro history matters only insofar as it affects human life.

Bad representation:

> Britain War Power: 72

Preferred representation:

-   food prices increase,
-   the player's brother is eligible for military service,
-   a factory shifts to war production,
-   working hours increase,
-   unemployment changes,
-   disease spreads,
-   migration becomes more likely.

The player experiences history through personal consequences.

------------------------------------------------------------------------

## 3.2 Historical Constraints Are Gameplay

Historical restrictions must be mechanically meaningful.

A poor child in 1250 cannot simply click "Attend University."

Access can depend on:

-   age,
-   social position,
-   household wealth,
-   location,
-   legal rights,
-   sex/gender restrictions appropriate to the represented legal/social
    system,
-   family permission,
-   institutions,
-   education,
-   skills,
-   connections,
-   historical technology,
-   laws.

The player may sometimes overcome barriers, but barriers must actually
exist.

------------------------------------------------------------------------

## 3.3 No Correct Life

The game does not define wealth or prestige as the only victory
condition.

A life can become:

-   farmer,
-   factory worker,
-   criminal,
-   merchant,
-   soldier,
-   artisan,
-   doctor,
-   priest,
-   beggar,
-   shopkeeper,
-   aristocrat,
-   sailor,
-   artist,
-   servant,
-   entrepreneur,
-   etc.

A tragic or poor life may still be an excellent run if it creates a
memorable story.

Death is not failure by definition.

------------------------------------------------------------------------

## 3.4 One Life, One Run

Current locked direction:

-   The player begins a life.
-   The player lives until death.
-   Death ends the run.
-   A detailed life summary/timeline/family tree is shown.
-   The player does **not** automatically continue as a child.

Dynasty gameplay is explicitly postponed.

This is intentional.

The emotional payoff should come from reviewing the complete life that
was lived.

------------------------------------------------------------------------

# 4. Time Model

The primary progression mechanic is:

# `+1 YEAR`

ChronoLife is not currently a monthly or weekly simulator.

The annual tick is important because:

-   it keeps the interface accessible,
-   it supports long lifetimes,
-   it allows history to move visibly,
-   it prevents micro-management from overwhelming the player.

The simulation under the button can still be sophisticated.

------------------------------------------------------------------------

# 5. Player Activity Between Years

The player may inspect and interact with categories such as:

-   Relationships
-   Career
-   Education
-   Health
-   Activities
-   Crime
-   Finance
-   Property
-   Household
-   Character

Actions are generally queued/resolved as part of the annual simulation.

The player should not be able to infinitely spam meaningful actions in a
single year.

The exact action economy is **not yet locked**.

Potential direction:

-   domain-specific limits rather than one universal "5 AP" pool,
-   story-critical responses should not consume optional action budget,
-   childhood agency should be more constrained than adult agency.

Do not hard-code an arbitrary action-point number during Phase 0 unless
required for a minimal test.

------------------------------------------------------------------------

# 6. The Three Core Systems

The project now has three central pillars.

## 6.1 Household Simulation

The player is embedded in a household.

## 6.2 Consequence Propagation

State changes generate causal downstream effects.

## 6.3 Storylet + Utility System

The game selects relevant player-facing situations based on context
rather than drawing arbitrary random events.

These systems are more important than having hundreds of authored
events.

------------------------------------------------------------------------

# 7. Simulation Architecture Overview

Conceptual structure:

``` text
WORLD
  │
  ├── Economy
  ├── Disease
  ├── Employment
  ├── Food Prices
  ├── War / Historical Pressure
  ├── Technology
  └── Laws
  │
  ▼
HOUSEHOLD
  │
  ├── Income
  ├── Expenses
  ├── Savings
  ├── Debt
  ├── Housing
  ├── Food Security
  └── Living Standard
  │
  ▼
ACTORS
  │
  ├── Player
  ├── Tier-1 NPCs
  ├── Tier-2 NPCs
  └── Tier-3 deterministic population ghosts
  │
  ▼
STATE CHANGES
  │
  ▼
CONSEQUENCE ENGINE
  │
  ├── Hard Consequences
  └── Utility-Based Responses
  │
  ▼
STORYLET ENGINE
  │
  ▼
PLAYER CHOICE
  │
  ▼
IMMEDIATE + DEFERRED DELTAS
  │
  ▼
STATE COMMIT
  │
  ▼
LIFE HISTORY
```

------------------------------------------------------------------------

# 8. Annual Simulation Pipeline

The original 15-step linear mutation pipeline has been rejected as too
fragile.

The preferred architecture uses read/compute/delta/commit principles.

## Phase 1 --- World Tick

Advance macro context.

Responsibilities:

-   calendar progression,
-   historical timeline triggers,
-   economy drift,
-   employment conditions,
-   food-price changes,
-   disease pressure,
-   regional conditions,
-   law/technology flags when applicable.

The world changes first; actors then react to the new world.

------------------------------------------------------------------------

## Phase 2 --- Life Simulation

Read the current authoritative state and calculate proposed changes.

Possible responsibilities:

-   queued player actions,
-   household budget calculation,
-   household decisions,
-   NPC intentions,
-   education progression,
-   occupation progression,
-   relationship drift,
-   health exposure/checks.

Systems should preferably write to a `YearDelta`/delta buffer rather
than mutating authoritative state unpredictably throughout the tick.

------------------------------------------------------------------------

## Phase 3 --- Consequence Propagation

Process triggered state changes.

Examples:

-   actor death,
-   job loss,
-   income loss,
-   household deficit,
-   disease,
-   birth,
-   marriage,
-   migration,
-   injury,
-   loss of housing.

Use bounded propagation to prevent runaway loops.

Exact constants such as:

-   maximum depth,
-   maximum propagation count,
-   maximum effects per rule,

must remain **configuration values**, not permanently locked design
laws.

------------------------------------------------------------------------

## Phase 4 --- Storylet Selection & Player Resolution

Evaluate the resulting context.

Steps:

1.  filter eligible storylets,
2.  calculate utility scores,
3.  apply cooldown/family constraints,
4.  use deterministic weighted stochastic selection,
5.  present the most relevant situations,
6.  resolve player choices into deltas.

Do not simply choose the highest-scoring storylet every time.

Do not use unrestricted pure random selection either.

------------------------------------------------------------------------

## Phase 5 --- Commit & Logging

Apply approved deltas to authoritative state.

Then:

-   finalize the year,
-   age actors appropriately,
-   append life history,
-   generate yearly summary,
-   terminate the run if the player died.

------------------------------------------------------------------------

# 9. Immediate vs Deferred Consequences

A major architectural decision:

Not every downstream consequence must fully resolve within the same
annual tick.

Use two conceptual categories.

## Immediate Delta

May affect the current year immediately.

Examples:

-   actor dies,
-   actor is removed from household,
-   injury is acquired,
-   money is transferred,
-   relationship changes,
-   disease/condition acquired,
-   job is lost,
-   household income source disappears.

## Deferred Delta

Becomes authoritative for subsequent progression.

Examples:

-   long-term educational interruption,
-   changing peer group,
-   new career availability,
-   persistent social mobility effects,
-   household adaptation,
-   long-term skill consequences.

Example:

``` text
1858:
Father dies.
Household immediately loses his income.
Household pressure rises.
Family chooses/receives a response.

1859:
Education/career progression now runs against the newly committed household state.
```

This intentionally avoids complex same-year Phase 2 ↔ Phase 3 recursion
in the first implementation.

------------------------------------------------------------------------

# 10. Consequence Engine

This is the core differentiating simulation system.

## 10.1 Principle

The Consequence Engine must not simply hide scripted stories one layer
below the event system.

Bad:

``` text
father dies
→ player always leaves school
→ player always becomes child worker
```

Correct approach:

Some consequences are mechanically unavoidable.

Others are possible responses evaluated from state.

Example:

``` text
FATHER DIES
    ↓
Hard consequence:
household loses father's income
    ↓
Household deficit / survival pressure changes
    ↓
Possible responses:
- use savings
- take debt
- mother seeks additional work
- request help from relatives
- request institutional charity
- reduce living standard
- move housing
- send child to work
- interrupt education
```

Which response occurs depends on context.

Potential factors:

-   savings,
-   debt,
-   household size,
-   relatives,
-   household traits,
-   parent personality,
-   available jobs,
-   institutions,
-   social tier,
-   laws,
-   location,
-   player age,
-   relationship strength,
-   seed.

Thus the causal chain exists, but its path is not predetermined.

------------------------------------------------------------------------

## 10.2 Hard vs Behavioral Consequences

### Hard Consequence

Mechanically direct.

Examples:

``` text
income earner dies → their income disappears
house burns → housing is lost
hand crushed → physical condition acquired
job terminated → occupation income disappears
```

### Behavioral / Adaptive Response

Requires choice/utility/weighted resolution.

Examples:

``` text
household deficit →
    borrow?
    work more?
    child labor?
    ask relatives?
    move?
    accept worse nutrition?
```

This distinction must be preserved in implementation.

------------------------------------------------------------------------

## 10.3 Consequence Rule Concept

Illustrative schema:

``` json
{
  "id": "household_loses_income_on_member_death",
  "trigger": "actor_died",
  "conditions": [
    {
      "field": "deceased.is_household_member",
      "op": "==",
      "value": true
    },
    {
      "field": "deceased.income",
      "op": ">",
      "value": 0
    }
  ],
  "effects": [
    {
      "type": "remove_income_source",
      "target": "household",
      "actor": "$deceased"
    },
    {
      "type": "emit_trigger",
      "trigger": "household_income_changed"
    }
  ],
  "priority": 10
}
```

Typed effects are preferred over arbitrary script strings.

------------------------------------------------------------------------

# 11. Storylet Architecture

Three terms must remain separate.

## 11.1 Scripted Storylet

Specific authored situation.

Example:

-   father's deathbed conversation,
-   historically specific local incident,
-   unique career milestone.

Usually limited/restricted.

------------------------------------------------------------------------

## 11.2 Template Storylet

Reusable parameterized situation.

Examples:

-   workplace accident,
-   argument,
-   illness,
-   wage reduction,
-   romantic opportunity,
-   theft opportunity,
-   school conflict.

One template may generate many contextual variations.

------------------------------------------------------------------------

## 11.3 Emergent Narration

Not a storylet.

It simply explains what the simulation already caused.

Example:

> Your father's death removed the household's largest income source.
> Your family exhausted its savings and your living standard fell.

No decision is required.

This is generated from deterministic templates, not runtime LLM calls.

------------------------------------------------------------------------

# 12. Storylet Utility Scoring

Eligible storylets receive contextual utility.

Illustrative example:

``` json
{
  "id": "workplace_accident",
  "family": "workplace_accident",
  "requirements": {
    "occupation_tags": ["industrial"],
    "minimum_age": 10
  },
  "utility": {
    "base": 10,
    "modifiers": [
      {
        "condition": "workplace.safety < 0.25",
        "add": 20
      },
      {
        "condition": "actor.exhaustion > 60",
        "add": 15
      },
      {
        "condition": "actor.constitution < 40",
        "add": 10
      }
    ]
  }
}
```

Selection concept:

``` text
eligible candidates
→ utility calculation
→ deterministic weighted stochastic selection
→ family/cooldown restrictions
→ 1–N meaningful situations
```

Softmax is a candidate method, not yet a permanently fixed
implementation requirement.

Any temperature/weight constants must be configurable and empirically
tested.

------------------------------------------------------------------------

# 13. RNG & Determinism

Determinism is important for:

-   reproducible bugs,
-   automated balancing,
-   sharing seeds,
-   regression testing.

Never use one global RNG stream for every system.

Preferred conceptual streams:

``` text
master_seed

world_rng(year)
household_rng(household_id, year)
actor_rng(actor_id, year)
health_rng(actor_id, year)
consequence_rng(trigger_id, year)
storylet_rng(year)
```

These should be derived deterministically from stable identifiers.

Adding a new random roll to one system should not completely alter every
other system's future output.

Implementation may use hash-derived seeds/streams.

Exact RNG implementation is a technical decision, but reproducibility is
mandatory.

------------------------------------------------------------------------

# 14. Character Model

## 14.1 Visible Stats

Current target:

-   Health
-   Happiness / Morale
-   Intelligence / Intellect
-   Physical
-   Appearance

Terminology can be standardized later.

Avoid 20+ visible bars.

------------------------------------------------------------------------

## 14.2 Core Hidden/Persistent Biology

Keep the MVP small.

Primary persistent values:

-   Constitution
-   Willpower
-   Genetic Seed

Do **not** persist many overlapping hidden values such as:

-   immunity,
-   disease resistance,
-   longevity modifier,
-   addiction susceptibility,
-   risk tolerance,

unless they become independently necessary.

Prefer deriving them from existing state.

Examples:

``` text
immunity =
    f(constitution, age, nutrition, conditions)

risk_tolerance =
    f(traits, willpower, age, current_pressure)

fertility =
    f(age, health, genetic_seed)
```

------------------------------------------------------------------------

## 14.3 Genetics

Do not build a genetics simulator in Phase 0.

MVP representation:

``` text
genetic_seed: uint64
constitution: numeric value
```

When a deterministic latent factor is needed:

``` text
derive_genetic_factor(genetic_seed, "fertility")
derive_genetic_factor(genetic_seed, "appearance")
```

Expand genetics only when gameplay requires it.

------------------------------------------------------------------------

# 15. Traits

Traits represent personality.

Examples:

-   Ambitious
-   Shy
-   Brave
-   Cowardly
-   Greedy
-   Loyal
-   Jealous
-   Charismatic
-   Honest
-   Deceitful
-   Hardworking
-   Lazy

Traits may affect:

-   utility scoring,
-   NPC decisions,
-   household responses,
-   relationship behavior,
-   crime,
-   career,
-   event options.

Traits can occasionally be acquired/lost.

Do not confuse traits with skills or temporary health conditions.

------------------------------------------------------------------------

# 16. Skills

Skills are learned capabilities.

Long-term examples:

-   Literacy
-   Numeracy
-   Craftsmanship
-   Trade
-   Combat
-   Medicine
-   Agriculture
-   Oratory
-   Music
-   Navigation
-   Engineering

Phase 0 requires only a tiny subset.

Potential initial set:

-   Literacy
-   Numeracy
-   Craftsmanship
-   Street Smarts
-   Discipline

Exact Phase 0 list may be reduced further if unnecessary.

Skills must be gated by era/content availability.

------------------------------------------------------------------------

# 17. Health Model

Health should not be only a percentage.

Actors can have conditions.

Examples:

-   tuberculosis,
-   cholera,
-   malnutrition,
-   broken bone,
-   work injury,
-   influenza,
-   pregnancy,
-   alcoholism.

A condition can contain:

``` text
severity
duration
mortality
contagiousness
stat effects
treatment availability
```

Historical treatment effectiveness belongs in era/content rules.

Phase 0 should use only a few conditions sufficient to test the
architecture.

------------------------------------------------------------------------

# 18. Household Economy

Household simulation is central.

The player does not exist economically in isolation, especially during
childhood.

Illustrative household:

``` text
THOMPSON HOUSEHOLD — 1858

Income:
Father, textile worker       +£31
Mother, sewing               +£11
William, school                £0

Expenses:
Housing                      -£16
Food                         -£22
Heating                       -£5
Other                         -£2

Net                          -£3
Savings                       £1
Debt                          £0
```

Relevant state:

``` text
members
income_sources
expenses
savings
debt
housing_quality
food_security
living_standard
location
```

------------------------------------------------------------------------

# 19. Living Standard

Possible tiers:

``` text
Destitute
Poor
Basic
Comfortable
Affluent
Luxury
```

Living standard should be derived from actual economic conditions rather
than being a manually arbitrary status.

It may affect:

-   nutrition,
-   disease exposure,
-   child mortality,
-   happiness,
-   education access,
-   social opportunities,
-   housing quality.

------------------------------------------------------------------------

# 20. Childhood Agency

Children should not have adult-level authority.

This is a key design feature rather than a limitation.

Example:

A 9-year-old poor child may be removed from school by a parent.

The player may receive limited responses such as:

-   accept,
-   protest,
-   ask the other parent for help,
-   seek outside assistance.

Outcome can depend on:

``` text
age
willpower
parent traits
relationship
household pressure
institution access
era rules
```

The player's agency should increase with age and legal/social
independence.

Phase 0 does not need a complete childhood-choice system, but
architecture must not assume every actor controls their own household
decisions.

------------------------------------------------------------------------

# 21. NPC Simulation & LOD

Do not simulate an entire city as full characters.

## Tier 1 --- Important Actors

Examples:

-   parents,
-   spouse,
-   children,
-   closest friend,
-   important enemy.

Full-ish lightweight simulation:

-   age,
-   health,
-   traits,
-   skills where relevant,
-   occupation,
-   household membership,
-   relationships,
-   life status.

Expected count is small.

------------------------------------------------------------------------

## Tier 2 --- Known Actors

Examples:

-   coworkers,
-   landlord,
-   neighbor,
-   boss,
-   acquaintances.

Store summary-level state.

Possible fields:

``` text
id
seed
age
sex
occupation
affinity
alive
basic social status
```

------------------------------------------------------------------------

## Tier 3 --- Background Population

No full persistent state.

Generated deterministically when needed.

However, a Tier-3 entity should have enough deterministic identity
information that promotion does not create an obviously contradictory
history.

------------------------------------------------------------------------

# 22. LOD Promotion

NPC importance can change.

Tier 2 → Tier 1 when:

-   romance becomes serious,
-   marriage occurs,
-   rivalry becomes major,
-   mentor relationship forms,
-   family connection forms,
-   repeated story relevance emerges.

Promotion should reconstruct additional details deterministically from
the NPC's seed/context rather than inventing an unrelated new person.

Tier 1 → Tier 2 demotion may later summarize state rather than deleting
identity.

Phase 0 may implement only the data shape, not the full promotion
lifecycle.

------------------------------------------------------------------------

# 23. Relationships

LOD-aware relationship model.

## Tier 1

Potential dimensions:

``` text
Closeness
Trust
Attraction
```

Relationships may be asymmetric.

Example:

``` text
Player trusts John: 90
John trusts Player: 34
```

Attraction is nullable/not applicable for non-romantic relationships.

## Tier 2

Single scalar:

``` text
Affinity
```

## Tier 3

No persistent relationship state.

Phase 0 does not need full relationship simulation.

------------------------------------------------------------------------

# 24. Reputation

One global reputation number is insufficient long-term.

Potential contextual domains:

-   family,
-   legal,
-   neighborhood,
-   workplace,
-   religious institution,
-   guild/faction.

Most should not clutter the main UI.

This system is **not a Phase 0 requirement**.

Architecture should avoid assuming reputation is necessarily one scalar.

------------------------------------------------------------------------

# 25. Institutions

Human life occurs inside institutions as well as households.

Possible institutions:

-   factory/workplace,
-   school,
-   church/religious organization,
-   guild,
-   court,
-   police,
-   military,
-   charity,
-   local authority.

Long-term conceptual schema:

``` text
Institution
  id
  type
  location
  influence
  services
  entry conditions
  rights/obligations
  actor standing
```

Institutions can influence storylets and consequences.

Do not build a large institution framework during the first kernel test
unless needed.

------------------------------------------------------------------------

# 26. Social Class / Social Position

Social class is real gameplay, not cosmetic flavor.

Universal abstraction may use tiers.

Example conceptual levels:

``` text
Lower
Working
Middle
Wealthy
Elite
```

Era-specific labels can differ.

Examples:

Medieval:

-   serf,
-   peasant,
-   artisan,
-   merchant,
-   clergy,
-   nobility.

Roman:

-   slave,
-   freedman,
-   plebeian,
-   equestrian,
-   patrician.

Social mobility should depend on:

-   household wealth,
-   occupation,
-   education,
-   property,
-   marriage,
-   reputation,
-   connections,
-   legal status.

Do not implement "earn X money = automatically elite."

------------------------------------------------------------------------

# 27. Rights Matrix / Legal Status

Era-specific social structures should ultimately expose
capabilities/rights rather than forcing the universal engine to know
every historical class.

Potential rights:

``` text
movement freedom
property ownership
marriage eligibility
legal personhood
education access
occupation eligibility
inheritance eligibility
trial rights
military obligations
```

This is important for future eras such as Rome and medieval Europe.

------------------------------------------------------------------------

# 28. Era Architecture

Each historical period is **not** a separate game.

Preferred layering:

``` text
UNIVERSAL SIMULATION CORE
        ↓
BASE CONTENT
        ↓
ERA RULESET
        ↓
REGION OVERRIDE
        ↓
SETTLEMENT OVERRIDE
```

Example:

``` text
Universal occupation template
        ↓
Industrial Britain
        ↓
Lancashire
        ↓
Manchester
```

The core defines mechanics.

Data defines historical content.

------------------------------------------------------------------------

# 29. Content Inheritance / Override Rules

Proposed semantics:

## Scalar

Replace.

## Object

Deep merge.

## Array

Replace by default.

Explicit operations may support:

``` text
$append
$remove
```

Do not implement an overly clever inheritance DSL during Phase 0 unless
required.

The important architectural goal is avoiding duplicate complete
definitions for every era.

------------------------------------------------------------------------

# 30. Declarative Era Contract

The universal simulation must not hard-code assumptions such as:

-   everyone can marry at 18,
-   everyone can own property,
-   everyone can attend school,
-   everyone can freely migrate.

Most era behavior should be declarative.

Conceptual examples:

``` text
can_marry
minimum_marriage_age
property_rights
education_access
child_labor_rules
inheritance_rules
migration_rules
legal_status
occupation_restrictions
```

Target philosophy:

-   \~95% data/rules,
-   small controlled extension surface for genuinely exceptional
    historical mechanics.

------------------------------------------------------------------------

# 31. Custom Era Behavior

Some historical systems may not fit flat declarative rules.

Examples:

-   Roman slavery/manumission,
-   complex feudal obligations,
-   caste-like legal systems,
-   unusual inheritance systems.

Do not allow arbitrary era scripts to infect the core.

If custom behavior becomes necessary, expose a **small, named, closed
set of extension hooks**.

Conceptual examples:

``` text
validate_marriage(...)
resolve_inheritance(...)
get_legal_status(...)
validate_property_ownership(...)
validate_occupation(...)
```

This is a future architecture concern; Phase 0 does not need multiple
era adapters.

------------------------------------------------------------------------

# 32. Historical Timeline

Macro history is primarily fixed.

The player does not rewrite major world history in the initial design.

Historical events modify state.

Example:

``` text
War begins
→ food prices change
→ employment composition changes
→ military eligibility changes
→ household economics change
→ personal consequences emerge
```

Avoid direct simplistic effects such as:

``` text
war starts → happiness -20
```

The simulation should carry the effect.

------------------------------------------------------------------------

# 33. Geography

Hierarchy:

``` text
Country
  ↓
Region
  ↓
Settlement
```

Location can affect:

-   occupation availability,
-   wages,
-   cost of living,
-   disease,
-   crime,
-   institutions,
-   education,
-   historical exposure.

Initial implementation:

``` text
Britain
→ Lancashire
→ Manchester
```

Phase 0 can treat Manchester as the only settlement.

------------------------------------------------------------------------

# 34. Era Development Strategy

Historical periods are developed incrementally.

Initial planned progression concept:

1.  Industrial Britain
2.  Medieval period
3.  Roman period
4.  1900--1950
5.  1950--2000
6.  Contemporary era

Possible later expansions:

-   Renaissance,
-   Viking Age,
-   Ancient Greece,
-   Ottoman periods,
-   Age of Exploration,
-   other regional packs.

Do not build these now.

------------------------------------------------------------------------

# 35. Cross-Era Lives

Cross-era transitions are **not** part of MVP.

However, do not freeze the world artificially at 1900 and simulate
another 60 years with unchanged 1900 conditions.

Preferred eventual strategy:

-   Era/content support ranges can overlap.
-   Example:
    -   Industrial Britain content: roughly 1830--1930
    -   20th Century Britain: roughly 1900 onward
-   Starting birth years can initially be constrained so normal
    lifetimes remain inside supported content.

Example:

``` text
Industrial Britain support:
1830 ---------------- 1930

Allowed initial births:
1850 ------ 1870
```

Thus a player born in 1857 can naturally die in the early 20th century
without requiring a full cross-era transition engine immediately.

Exact historical ranges are content/design decisions and should not be
treated as already researched facts.

------------------------------------------------------------------------

# 36. Death

Death ends the run.

Death can come from:

-   disease,
-   age,
-   accident,
-   violence,
-   war,
-   childbirth,
-   other era-specific causes.

On death, produce a `LifeResult`.

Potential summary:

``` text
Name
Birth year
Death year
Age
Cause of death
Occupations
Education
Partners
Children
Household history
Property
Major conditions
Major relationships
Major life events
Lifetime economic trajectory
```

------------------------------------------------------------------------

# 37. Life Timeline

Important events are recorded throughout life.

Example:

``` text
1851 — Born in Manchester.
1858 — Began basic schooling.
1860 — Father died.
1861 — Left school.
1861 — Began factory work.
1868 — Became a machine operator.
1873 — Married.
1875 — First child born.
1890 — Became foreman.
1908 — Died aged 57.
```

Not every trivial state change belongs in the timeline.

Possible importance levels:

``` text
TRIVIAL
MINOR
MAJOR
LIFE_DEFINING
```

------------------------------------------------------------------------

# 38. Family Tree

Long-term presentation feature.

Track:

-   parents,
-   siblings,
-   partner(s),
-   children,
-   important descendants where relevant to the final tree.

The player does not continue as them in current design.

Phase 0 only needs enough family data to support parents/siblings and
later expansion.

------------------------------------------------------------------------

# 39. Crime

Long-term domain.

Potential crimes:

-   theft,
-   fraud,
-   assault,
-   smuggling,
-   murder,
-   era-specific offenses.

Potential causal chain:

``` text
crime
→ detection
→ investigation
→ arrest
→ trial
→ punishment
→ contextual reputation effects
```

Law must be era-aware.

Do not implement full crime in Phase 0.

------------------------------------------------------------------------

# 40. Education

Education paths are era-dependent.

Industrial examples:

-   no schooling,
-   Sunday/basic school,
-   apprenticeship,
-   advanced/private education,
-   university.

Access may depend on:

-   household economy,
-   social class,
-   age,
-   legal rules,
-   location,
-   institutions,
-   family decisions.

Phase 0 only needs enough education state to test:

``` text
in school
not in school
education interrupted
basic literacy progression
```

------------------------------------------------------------------------

# 41. Occupation System

Occupations must be data-driven.

The core must not contain special logic for "textile worker."

Illustrative occupation data:

``` json
{
  "id": "textile_worker",
  "tags": ["industrial", "manual_labor"],
  "minimum_age": 9,
  "income_range": [18, 35],
  "health_risk": 0.22,
  "skill_progression": {
    "craftsmanship": 2
  },
  "advancement": [
    "machine_operator"
  ]
}
```

Phase 0 needs only a few occupations.

Suggested minimum:

-   unemployed/dependent,
-   textile worker,
-   child factory worker/piecer,
-   perhaps one slightly better occupation.

The goal is architecture testing, not content volume.

------------------------------------------------------------------------

# 42. World State

Phase 0 world variables can be minimal.

Suggested:

``` text
economy_index
food_price_index
employment_pressure
disease_pressure
```

Possibly:

``` text
industrial_safety
```

Do not simulate a grand-strategy world.

World state exists only to meaningfully affect individual lives.

------------------------------------------------------------------------

# 43. Headless Simulation

The simulation must be executable without UI.

Core target:

``` text
simulate_life(seed) -> LifeResult
```

And batch mode:

``` text
simulate_many(start_seed, count)
```

Initial goal:

-   10 lives for debugging,
-   100 lives for sanity checking,
-   eventually 1,000+ for balance.

Do not prematurely optimize for 10,000 runs before the simulation is
correct.

------------------------------------------------------------------------

# 44. Automated Metrics

Potential metrics:

-   lifespan distribution,
-   childhood mortality,
-   occupation distribution,
-   household deficit frequency,
-   education interruption,
-   disease prevalence,
-   social mobility,
-   marriage rate later,
-   children later,
-   income/living-standard trajectory.

Important:

The first purpose of automated simulation is **not** perfect historical
calibration.

It is to catch absurdities such as:

-   impossible ages,
-   dead actors earning wages,
-   negative household members,
-   everyone becoming wealthy,
-   nobody dying,
-   every child working,
-   recursive consequence explosions,
-   inconsistent deterministic output.

Historical calibration requires separate research.

------------------------------------------------------------------------

# 45. Content Validation

As content grows, automatic linting will be necessary.

Potential checks:

-   missing referenced IDs,
-   impossible requirements,
-   invalid ranges,
-   circular advancement references,
-   missing localization keys,
-   storylet with no valid outcome,
-   consequence rule emitting unknown trigger,
-   illegal duplicate IDs.

Phase 0 should at least fail loudly on invalid critical data.

------------------------------------------------------------------------

# 46. Runtime LLM Policy

Runtime LLM-generated story content is **not** part of the design.

Reasons:

-   determinism,
-   cost,
-   latency,
-   inconsistent tone,
-   QA difficulty,
-   save/replay problems.

LLMs may be used during development to help author content, but shipped
simulation output should use authored/templated deterministic content
unless this decision is explicitly revisited later.

------------------------------------------------------------------------

# 47. Mod Support

Mod support is not an MVP feature.

Architecture should avoid unnecessary barriers to future data packs.

Do not build:

-   public mod API,
-   workshop integration,
-   plugin SDK,

during Phase 0.

------------------------------------------------------------------------

# 48. Tone

Historical world:

-   serious,
-   grounded,
-   plausible.

Individual lives may naturally become:

-   funny,
-   tragic,
-   absurd,
-   romantic,
-   brutal,
-   uplifting.

The game should not constantly make jokes.

Comedy should usually emerge from life situations rather than parodying
history.

------------------------------------------------------------------------

# 49. Historical Accuracy Philosophy

The project is not attempting to become an academic population
simulator.

Priority order:

1.  Plausible human simulation
2.  Good gameplay
3.  Historical authenticity
4.  Fine-grained historical exactness

Avoid obvious anachronisms.

Do not invent precise historical numbers without research.

All historical balance constants should be treated as tunable data.

------------------------------------------------------------------------

# 50. Scope Control

Do **not** attempt:

-   full city simulation,
-   millions of NPCs,
-   real-time daily life,
-   3D world,
-   grand strategy,
-   every historical event,
-   all eras simultaneously,
-   hundreds of occupations before the kernel works,
-   hundreds of storylets before the kernel works.

The project succeeds if one human life feels causally coherent and
memorable.

------------------------------------------------------------------------

# 51. Phase 0 --- Exact Implementation Goal

## ChronoLife Simulation Kernel

Setting:

**1850 Manchester test environment**

This is a technical sandbox, not yet a historically complete content
pack.

### Required simulation entities

-   one player,
-   two parents where generated/alive,
-   optional 0--3 siblings,
-   one household,
-   one settlement/world state.

### Required actor data

Minimum useful fields:

``` text
id
name
birth_year
age
sex
alive
health
constitution
willpower
genetic_seed
traits
occupation_id
education_state
income
household_id
conditions
```

Exact schema may be refined before coding.

### Required household data

``` text
id
member_ids
income
expenses
savings
debt
food_security
living_standard
location_id
```

### Required world state

``` text
year
economy_index
food_price_index
employment_pressure
disease_pressure
```

### Required occupation content

At least:

-   dependent/unemployed,
-   textile worker,
-   child factory worker.

Optional fourth occupation if useful for testing mobility.

### Required education states

At least:

-   none,
-   basic schooling,
-   interrupted/left school.

### Required conditions

Small test set:

-   malnutrition,
-   cholera or generic epidemic disease,
-   tuberculosis or chronic disease,
-   workplace injury.

Do not overbuild medicine.

### Required consequence categories

At minimum:

-   actor death,
-   income loss,
-   job loss,
-   household deficit,
-   food insecurity,
-   disease,
-   school interruption,
-   child labor response,
-   household adaptation,
-   optional migration pressure if easy.

### Required storylets

Approximately 5--10 only.

Enough to test:

-   utility filtering,
-   cooldowns,
-   player choice structure,
-   deterministic selection.

### Required logging

Every year should be debuggable.

Example debug output:

``` text
YEAR 1860
WORLD:
  food_price_index: 1.18

HOUSEHOLD:
  income: 39
  expenses: 42
  surplus: -3
  savings: 2

TRIGGERS:
  household_deficit

CONSEQUENCES:
  savings_used: 2
  food_security -> fragile

STORYLET:
  household_financial_pressure

COMMIT COMPLETE
```

------------------------------------------------------------------------

# 52. Phase 0 Success Criteria

Phase 0 is successful when:

1.  `simulate_life(seed)` can run a player from birth until death.
2.  The same seed produces the same result.
3.  Different seeds produce meaningfully different trajectories.
4.  A household income loss creates logical downstream pressure.
5.  Consequences do not require giant hard-coded life scripts.
6.  Child education/work state can react to household pressure.
7.  Health conditions can influence mortality.
8.  Dead actors stop contributing income/actions.
9.  No uncontrolled consequence recursion occurs.
10. Life history explains major state changes.
11. Batch simulation can run many lives without UI.
12. Tests catch obvious state invariants.

------------------------------------------------------------------------

# 53. Required Invariants

Examples the implementation should test:

``` text
actor.age >= 0
dead actor cannot have active occupation income
household income == sum(valid income sources)
household savings >= 0 unless model explicitly allows otherwise
player belongs to exactly one active household
dead actor cannot die twice
current year never moves backward
same seed + same content version = same result
no consequence propagation exceeds configured limits
```

Add further invariants when discovered.

------------------------------------------------------------------------

# 54. Suggested Technical Modules

Names are suggestions, not mandatory filenames.

``` text
simulation/
  simulation_state.gd
  simulation_runner.gd
  year_tick.gd
  year_delta.gd

actors/
  actor_state.gd
  actor_factory.gd

household/
  household_state.gd
  household_system.gd

world/
  world_state.gd
  world_system.gd

health/
  health_system.gd
  condition_definition.gd

career/
  occupation_definition.gd
  career_system.gd

education/
  education_system.gd

consequences/
  consequence_engine.gd
  consequence_rule.gd
  consequence_trigger.gd

storylets/
  storylet_engine.gd
  storylet_definition.gd
  utility_evaluator.gd

rng/
  deterministic_rng.gd

history/
  life_history.gd
  life_event.gd

content/
  content_registry.gd
  validation/

tests/
  simulation/
```

Do not create dozens of empty abstractions just to match this diagram.

Prefer the smallest architecture that cleanly preserves the boundaries.

------------------------------------------------------------------------

# 55. Godot-Specific Direction

This is a simulation-heavy project.

Avoid representing every actor as a Node in the SceneTree.

Preferred philosophy:

-   simulation data is plain/ref-counted/resource-like state,
-   services/systems operate on state,
-   UI later observes simulation state,
-   no `_process()` per NPC,
-   annual ticks are explicit function calls,
-   simulation can run thousands of years/lives without rendering.

The headless simulation should not require a loaded gameplay scene.

------------------------------------------------------------------------

# 56. Save Architecture Direction

Not a Phase 0 priority, but state should eventually serialize cleanly.

Conceptual save:

``` json
{
  "version": "0.2",
  "content_version": "industrial_test_0.1",
  "master_seed": 83917482,
  "world_state": {},
  "player": {},
  "household": {},
  "tier1_npcs": [],
  "tier2_npcs": [],
  "storylet_cooldowns": {},
  "life_history": [],
  "pending_deltas": []
}
```

Do not optimize save size prematurely.

------------------------------------------------------------------------

# 57. Future MVP After Phase 0

Only after the kernel proves itself, expand toward:

-   richer family simulation,
-   marriage,
-   children,
-   relationships,
-   8--10 occupations,
-   8--10 traits,
-   \~6 skills,
-   \~6--8 health conditions,
-   3 education paths,
-   3 social classes,
-   basic institutions,
-   crime,
-   richer historical timeline,
-   15--20 scripted storylets,
-   25--30 reusable template storylets,
-   timeline UI,
-   family tree,
-   save/load,
-   final presentation.

------------------------------------------------------------------------

# 58. Explicitly Deferred Features

Do not implement during Phase 0:

-   Dynasty / playing as child after death
-   Full cross-era transition system
-   Runtime LLM generation
-   Mental health simulation
-   Mod API
-   Multiple historical eras
-   Full crime/legal simulation
-   Deep institution system
-   Complex contextual reputation
-   Full genetics simulation
-   Detailed property system
-   Final UI
-   Final localization pipeline
-   Achievement/challenge system

------------------------------------------------------------------------

# 59. First Historical Content Strategy

First serious content target:

**Industrial Britain / Manchester-centered life simulation**

Original design focus was roughly 1850--1900.

To avoid artificial hard era endings, eventual content support should
likely extend beyond the player's allowed starting-birth window.

Do not currently assume a frozen 1900 epilogue.

Cross-era content overlap can be designed later.

------------------------------------------------------------------------

# 60. Why Manchester / Industrial Britain First?

It stresses many important life systems in one understandable setting:

-   industrial labor,
-   household poverty,
-   child labor,
-   education,
-   urbanization,
-   disease,
-   workplace injury,
-   social mobility,
-   changing technology,
-   crime,
-   class,
-   migration,
-   family economics.

Thus it is a good architecture test.

------------------------------------------------------------------------

# 61. Core Example: The Kind of Emergent Life We Want

Illustrative output:

``` text
1851 — William Thompson was born in Manchester.

1855 — His younger sister died during a disease outbreak.

1858 — His father's wages fell as factory employment weakened.

1859 — The household exhausted most of its savings.

1860 — William's father suffered a severe workplace injury.

1860 — The household lost its largest income source.

1861 — William's mother increased her sewing work.

1861 — William left school as the household struggled to afford food.

1861 — William began working as a factory child worker.

1867 — William became a textile worker.

1872 — Household finances stabilized.

1875 — William married.

1881 — He became a machine operator.

1890 — He advanced to foreman.

1908 — William died aged 57.
```

This exact life should **not** be scripted.

The engine should be capable of producing it through:

``` text
world pressure
+ household economics
+ actor state
+ hard consequences
+ adaptive responses
+ storylet decisions
+ deterministic randomness
```

Another seed should plausibly produce a completely different life.

------------------------------------------------------------------------

# 62. Architectural Failure Modes to Avoid

## Failure: Historical BitLife

Symptoms:

-   most changes come from random popup events,
-   simulation state barely matters,
-   choices directly add/subtract stats,
-   era is mostly flavor text.

Reject.

## Failure: Hidden Scripted Story

Symptoms:

``` text
father dies → fixed chain → factory worker
```

Consequence Engine becomes disguised quest scripting.

Reject.

## Failure: Over-Simulation

Symptoms:

-   hundreds of world variables,
-   full city population,
-   every NPC has full AI,
-   months/days simulated despite annual UI.

Reject.

## Failure: Bespoke Era Code

Symptoms:

``` text
if era == "rome":
if era == "medieval":
if era == "industrial":
```

throughout core systems.

Reject.

## Failure: Data-Driven Theater

Symptoms:

-   JSON exists,
-   but core code contains special cases for every content ID.

Reject.

## Failure: RNG Fragility

Symptoms:

Adding one random roll to health completely changes all future storylets
for the same seed.

Reject.

------------------------------------------------------------------------

# 63. Phase 0 Deliverables Expected From Coding Agent

When implementing Phase 0, provide:

1.  Working project/kernel code.
2.  Clear directory structure.
3.  Headless simulation entry point.
4.  Deterministic RNG implementation.
5.  Actor/Household/World state.
6.  YearDelta model.
7.  Basic Consequence Engine.
8.  Small data-driven content set.
9.  Minimal Storylet/Utility prototype.
10. Life history/logging.
11. Automated tests.
12. Batch simulation command/test harness.
13. Example logs from at least 3 seeds.
14. `PHASE_0_REPORT.md`.

`PHASE_0_REPORT.md` should include:

-   architecture implemented,
-   files created/modified,
-   assumptions made,
-   deviations from this plan,
-   tests,
-   known bugs,
-   performance,
-   sample life summaries,
-   recommended next task.

------------------------------------------------------------------------

# 64. Implementation Discipline

If the coding agent encounters ambiguity:

-   prefer simple extensible behavior,
-   document the decision,
-   avoid inventing major gameplay systems,
-   do not silently reinterpret the design.

If a requested architecture proves unnecessarily complex for Phase 0,
simplify the implementation while preserving:

-   deterministic simulation,
-   explicit state,
-   delta-based mutation,
-   causal consequences,
-   household economics,
-   headless execution.

------------------------------------------------------------------------

# 65. Current Locked Decisions

The following should be treated as intentional unless explicitly
revisited:

-   One individual per run.
-   Death ends the run.
-   No Dynasty in current version.
-   `+1 Year` progression.
-   History affects personal life systemically.
-   Macro history is mostly fixed.
-   Household economy is central.
-   Important NPCs are actually simulated.
-   NPC simulation uses LOD.
-   Consequence Propagation is mandatory.
-   Consequence paths are not always deterministic.
-   Storylet + Utility architecture.
-   Emergent narration is distinct from storylets.
-   Runtime LLM generation is excluded.
-   Deterministic RNG streams.
-   Data-driven content.
-   Core → Base → Era → Region → Settlement conceptual hierarchy.
-   Declarative era rules preferred.
-   Controlled extension hooks only where required.
-   No full cross-era implementation yet.
-   No frozen-world epilogue solution.
-   Headless simulation before final UI.
-   Industrial Manchester is the first proving ground.
-   Phase 0 must stay small.

------------------------------------------------------------------------

# 66. Immediate Next Step

Do **not** implement the complete GDD.

Implement:

# TASK 01 --- PHASE 0: HEADLESS SIMULATION KERNEL

First prove this statement:

> A single household and one player can live through decades of annual
> simulation, with household economics, health, mortality, and bounded
> causal consequences producing coherent but seed-dependent life
> histories without relying on large scripted event chains.

Once that works, the project may proceed to Core Life systems.

Until then, content quantity is irrelevant.

------------------------------------------------------------------------

# 67. Final Product Vision

Long-term, a player should be able to press:

> **Random Life**

and receive something like:

-   1287 --- child of an English peasant household,
-   163 CE --- enslaved child in the Roman world,
-   1871 --- industrial working-class child in Manchester,
-   1964 --- middle-class modern household,
-   etc.

The same conceptual Life Engine should support these lives through
different content/rule layers.

The final question presented by the game is simple:

> **You were born into this world. What becomes of this life?**

ChronoLife succeeds when the answer is not authored in advance.
