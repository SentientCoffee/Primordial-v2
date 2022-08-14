package shadercomp

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
    fmt.printf("\nHellope from shadercomp in \x1b[1m{}\x1b[0m\n", os.get_current_directory())
    buf, ok := os.read_entire_file("assets/shaders/triangle.glsl")
    if !ok {
        fmt.printf("Failed to read file \"{}\"!\n", "triangle.glsl")
        os.exit(1)
    }
    // fmt.printf("\n>>>>>\n{}\n<<<<<\n", string(buf))

    sr : strings.Reader
    strings.reader_init(&sr, string(buf))

    fmt.println(">>>>>")
    for {
        idx := strings.index(string(buf), "\n")
        if idx == -1 { break }
        line := buf[:idx]

        fmt.printf("{}\n", string(line))

        buf = buf[idx+1:]
    }
    fmt.println("<<<<<")
}
