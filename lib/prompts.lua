local prompts = {}

prompts.synopsis_prompt = [[
Generate a lengthy novel synopsis from the following:
]]

prompts.scoring_prompt = [[
You are evaluating novel synopses for development priority. The goal is NOT to judge writing quality, grammar, or polish. The synopsis is only a rough idea. Assign an integer score from 1–100 for each category. Be extremely harsh with your scoring.

1. Hook
2. Originality
3. Memorability
4. Expansion Potential
5. Conflict Potential
6. Character Potential
7. Worldbuilding Potential
8. Emotional Potential
9. Curiosity
10. Overall Promise

Guidelines:
- Avoid clustering scores near the middle. Use the full 1–100 range.
- A score around 50 represents an average publishable premise.
- Scores above 85 should be rare and reserved for genuinely exceptional ideas.
- Scores below 25 should represent ideas with major conceptual weaknesses.
- Return only valid JSON.

Output format:

{
  "hook": 0,
  "originality": 0,
  "memorability": 0,
  "expansion_potential": 0,
  "conflict_potential": 0,
  "character_potential": 0,
  "worldbuilding_potential": 0,
  "emotional_potential": 0,
  "curiosity": 0,
  "overall_promise": 0
}
]]

return prompts
