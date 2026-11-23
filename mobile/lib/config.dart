/// The same Supabase project as the site (www.peera.my): one network, one database.
/// The key is the public one the site uses too; what anyone may do is decided by the database's own rules.
const supaUrl = 'https://iasospzhhdedpilykpiu.supabase.co';
const supaAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlhc29zcHpoaGRlZHBpbHlrcGl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzMzk3NzIsImV4cCI6MjEwNzkxNTc3Mn0.iHnk-s1ePtNWJrn0Md3svxbNa2vhUTATNxuS3VPUfhI';

/// Where the parts the app does not have yet open: the site.
const siteUrl = 'https://www.peera.my';

/// this build's number (the build machine's run, given with --dart-define=PEERA_BUILD=…); 0 on a developer's build
const appBuild = int.fromEnvironment('PEERA_BUILD');

/// where the app's newest version is announced: its number, what changed, the files and their checksums (the
/// repository's "app-dist" branch holds the newest signed files and this list, nothing else)
const updateFeed = 'https://raw.githubusercontent.com/bakakuri/sufra/app-dist/version.json';
