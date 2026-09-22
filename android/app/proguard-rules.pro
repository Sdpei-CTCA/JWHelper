# Room 在运行时通过反射调用 *_Impl 的无参构造器来实例化数据库,
# R8 看不到反射调用点,会把这个构造器当死代码删除,
# 导致 WorkManager 在应用启动时(androidx.startup 阶段)初始化崩溃闪退。
# room-runtime 2.5.0 自带的 consumer 规则只保类名不保构造器,这里显式补上。
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
