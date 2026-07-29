package imboy.chat;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Patrol 的 Android instrumentation 入口。
 *
 * <p>本文件是样板，不写业务断言——真正的测试用 Dart 写在 integration_test/ 下。
 * PatrolJUnitRunner 启动后会枚举 Dart 侧的 patrolTest 用例，每个用例作为一个
 * JUnit 参数化 case 在独立进程中运行（配合 build.gradle.kts 的
 * ANDROIDX_TEST_ORCHESTRATOR + clearPackageData）。
 *
 * <p>MainActivity 与本类同包（imboy.chat），故可直接引用。
 */
@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
