package shadercomp
import "core:fmt"
import "core:os"
main :: proc() {
    fmt.printf("\nHellope from shadercomp in \x1b[1m{}\x1b[0m\n", os.get_current_directory())
    buf, ok := os.read_entire_file("assets/shaders/triangle.glsl")
    if !ok {
        fmt.printf("Failed to read file \"{}\"!\n", "triangle.glsl")
        os.exit(1)
    }
    fmt.printf("\n>>>>>\n{}\n<<<<<\n", string(buf))
}
