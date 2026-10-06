# Rules for the release build's code shrinker.

# The ads library schedules background work through WorkManager, which
# builds its Room database by looking the generated class up by name.
# Without these the release app crashes the moment it opens
# ("Failed to create an instance of androidx.work.impl.WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
