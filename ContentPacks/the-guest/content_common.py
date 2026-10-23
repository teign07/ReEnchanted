"""Shared helpers for the November pack's manifest atoms."""

PACK_ID = "the-guest-november-2026"
EVENT_ID = "the-guest"

PHASE_ROLE = {
    "all-souls": "setup",
    "guest-right": "buildup",
    "the-offer": "climax",
    "the-bowl": "aftermath",
}


def world_gate(stage="live", min_day=None, max_day=None):
    world = {
        "eventIDs": [EVENT_ID], "runIDs": [], "phaseIDs": [], "phaseRoles": [],
        "lifecycleStages": [stage], "activationModes": [],
    }
    if min_day is not None:
        world["minimumLiveDay"] = min_day
    if max_day is not None:
        world["maximumLiveDay"] = max_day
    return {"allOf": [{"kind": "worldEvent", "worldEvent": world}], "anyOf": [], "noneOf": []}


def placement(phase=None, stage="live"):
    p = {"lifecycleStage": stage}
    if phase:
        p["phaseID"] = phase
        p["phaseRole"] = PHASE_ROLE[phase]
    return p


def atom(id, title, kind, channel, phase, min_day, max_day, *, interaction="none", priority="featured",
         voice="immediate", occurrence=None, tags=(), dependencies=(), stage="live", extra=None):
    a = {
        "id": id,
        "title": title,
        "reference": {"kind": kind, "id": id},
        "channel": channel,
        "placement": placement(phase, stage),
        "audience": "everyone",
        "voice": voice,
        "interaction": interaction,
        "priority": priority,
        "gate": world_gate(stage, min_day, max_day),
        "occurrence": occurrence or {"kind": "oncePerRun"},
        "dependencies": list(dependencies),
        "productionStatus": "ready",
        "isRequired": True,
        "tags": [EVENT_ID] + list(tags),
    }
    if extra:
        a.update(extra)
    return a


def needs(content_id, state="completed", policy="reportThenContinue"):
    return {"contentID": content_id, "requiredState": state, "scope": "sameRun",
            "minimumOccurrences": 1, "failurePolicy": policy}


def memory(entity, key, text, aside=None, gossip=None):
    m = {"entityID": entity, "key": key, "memory": text}
    if aside:
        m["aside"] = aside
    if gossip:
        m["gossip"] = gossip
    return m
