alter table public.reactions drop constraint reactions_emoji_check;
alter table public.reactions add constraint reactions_emoji_check check (emoji in ('👍','❤️','😂','😮','😢','😡','🍷'));
alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check check (target_type in ('post','comment','user','listing','message','page','story','event','job','ride','room','fixture'));
