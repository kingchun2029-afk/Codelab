import Foundation

struct Lesson: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let code: String
}

enum Lessons {
    /// 第一次打开时编辑区里的内容，不然一片空白不知道该写什么
    static let welcome = Lesson(
        title: "欢迎",
        note: "改改数字，再点运行。",
        code: """
        print("你好，这是我写的第一行");

        // rect(x, y, 宽, 高, 颜色)
        rect(20, 20, 80, 60, "#5ac8fa");

        // circle(圆心 x, 圆心 y, 半径, 颜色)
        circle(220, 100, 45, "#ffd60a");
        """
    )

    static let all: [Lesson] = [
        Lesson(
            title: "变量和输出",
            note: "变量是有名字的盒子：赋值就是往里放，用的时候拿名字取。",
            code: """
            // 变量就是一个有名字的盒子
            var hp = 100;
            var name = "小明";

            print("名字", name);
            print("血量", hp);

            hp = hp - 30;       // 取出 hp，减 30，再放回去
            print("挨了一刀后", hp);
            """
        ),
        Lesson(
            title: "循环：重复做",
            note: "for 拆开是三件事：从哪开始、做到什么条件、每次怎么变。",
            code: """
            // for (起点; 继续的条件; 每次怎么变)
            for (var i = 0; i < 5; i = i + 1) {
              print("第", i + 1, "次，i =", i);
            }
            """
        ),
        Lesson(
            title: "条件：分情况",
            note: "只执行条件成立的那一支，其余跳过。",
            code: """
            var score = 87;

            if (score >= 90) {
              print("A");
            } else if (score >= 80) {
              print("B");
            } else {
              print("C");
            }
            """
        ),
        Lesson(
            title: "函数：把步骤打包",
            note: "函数是「给同样的输入，做同样的事」；return 把结果交回去。",
            code: """
            function damage(hp, dmg) {
              return hp - dmg;
            }

            print("一刀", damage(100, 30));
            print("两刀", damage(damage(100, 30), 25));
            """
        ),
        Lesson(
            title: "数组：一串数",
            note: "数组按下标取，下标从 0 开始；length 是它有几个。",
            code: """
            var scores = [80, 92, 58];
            var total = 0;

            for (var i = 0; i < scores.length; i = i + 1) {
              total = total + scores[i];
            }

            print("总分", total);
            print("平均", total / scores.length);
            """
        ),
        Lesson(
            title: "画点东西",
            note: "逻辑画布 320×200，左上角是 (0,0)，y 往下增。",
            code: """
            clear();

            rect(20, 20, 80, 60, "#5ac8fa");    // x, y, 宽, 高, 颜色
            circle(220, 100, 45, "#ffd60a");    // 圆心 x, y, 半径, 颜色

            for (var i = 0; i < 5; i = i + 1) {
              rect(20 + i * 55, 140, 40, 40, "#ff453a");
            }
            """
        ),
    ]
}