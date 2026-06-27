"""Pydantic models = the wire contract the Flutter app binds to.

Mirror of the §7 contract in docs/todo/wisdom-project-rag-qa-design.md and the
Dart Freezed entities in lib/domain/entities/ask/. Keep these shapes aligned with
those entities — that alignment is precisely what keeps the backend swappable
(design §5.7, the "reversibility anchor").
"""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field


class HistoryTurn(BaseModel):
    """One prior conversation turn. Client-owned; empty in the prototype (§5.8)."""

    role: Literal["user", "assistant"]
    content: str


class Filters(BaseModel):
    """Optional hard metadata scope (design §5.9c). Only `basket` for now."""

    basket: Optional[str] = None


class AskRequest(BaseModel):
    """`POST /ask` request body. Matches AskRemoteDataSourceImpl in the app."""

    question: str
    history: list[HistoryTurn] = Field(default_factory=list)
    filters: Optional[Filters] = None


class Citation(BaseModel):
    """One grounded source. Mirrors lib/domain/entities/ask/citation.dart."""

    uid: str                          # "sn15.3" | "pli-tv-bu-vb-np18"
    ref: str                          # "SN 15.3" (display form)
    kind: str = "canon"               # "note" reserved for Sujato notes (§5.2)
    snippet: Optional[str] = None     # English source span (verification preview)
    deeplink: Optional[str] = None    # resolved later (resolver plan, Part D)


class AskResponse(BaseModel):
    """`POST /ask` response. Mirrors lib/domain/entities/ask/ask_answer.dart."""

    answer: str
    lang: Literal["si", "en"]
    citations: list[Citation] = Field(default_factory=list)
