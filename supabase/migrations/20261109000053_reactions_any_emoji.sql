-- reactions on posts, messages and stories may be any emoji (picked from the emoji panel), not only the few quick ones.
-- An emoji here: 1 to 16 code points, at least one of them from the emoji ranges, no letters (Latin or Georgian), spaces or markup.
create or replace function public.is_reaction_emoji(e text) returns boolean language sql immutable set search_path to '' as $f$
  select e is not null and char_length(e) between 1 and 16
    and e !~ '[[:space:]<>&"''A-Za-zႠ-ჿᲐ-Ჿⴀ-⴯]'
    and e ~ '[©®‼-㊙\U0001F000-\U0001FAFF]'
$f$;
alter table public.reactions drop constraint reactions_emoji_check, add constraint reactions_emoji_check check (public.is_reaction_emoji(emoji));
alter table public.message_reactions drop constraint message_reactions_emoji_check, add constraint message_reactions_emoji_check check (emoji is null or public.is_reaction_emoji(emoji));
alter table public.story_reactions drop constraint story_reactions_emoji_check, add constraint story_reactions_emoji_check check (public.is_reaction_emoji(emoji));
