class Nesc < Formula
  desc "Programming language for deeply networked systems"
  homepage "https://github.com/tinyos/nesc"
  url "https://github.com/tinyos/nesc/archive/refs/tags/v1.4.0.tar.gz"
  sha256 "ea9a505d55e122bf413dff404bebfa869a8f0dd76a01a8efc7b4919c375ca000"
  license "GPL-2.0-only"
  revision 2

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_golden_gate: "34b0edffefcd7c11899e5be0af9252f03c2de49779df3d39f2e074e69cdb4709"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:       "8ef4438f308a2fd9e143b70da8b9b53a0ca033c4d5a57182af79a2ad81e4fee3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia:     "ec7337c2f3b0ce8274e7ccc367aa35ba8930972f946e3e6d30fbd2dcfb728a09"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:      "586795d905da2511be52a64d753b1085c73149ee3b5f720aa19416f148b8cd8e"
    sha256 cellar: :any_skip_relocation, arm64_ventura:     "8a5476ebb9ff86e8aa35abe101f26893f3be3dc6cd709fd30d0012c778699a20"
    sha256 cellar: :any_skip_relocation, arm64_monterey:    "77716c3fa900dafb63734a8b40178b0fd8d263f1aa047869d6bf31d3941d03f8"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:     "b4d4450e60720f1c811afbf0a423de2809587d0a61bfdf73b2bd9b78054070cc"
    sha256 cellar: :any_skip_relocation, sonoma:            "1d0fdeb5a037662cb3ecafb289e2960ae2497930050654c71e64a3434250d970"
    sha256 cellar: :any_skip_relocation, ventura:           "4608c4e67325022c55a0f991afcad53aa00355a559b33dcfe6bdf61d0a883aed"
    sha256 cellar: :any_skip_relocation, monterey:          "77f2ceb7722575686a928f300064a5df68d46d89f97648662a90321e2aec179a"
    sha256 cellar: :any_skip_relocation, big_sur:           "9f1a0aa5ac89e1c7b0f278aaab584ce98dd4ae31a94fd9bb111287e8fcba8131"
    sha256 cellar: :any_skip_relocation, arm64_linux:       "a1bfde913670c487ed3a9f22f68189d9255b8ba6557f9100243ccdcb5182f83b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:      "09def7e758ed0e91c1557f6ee6994815db45bb14c9f3f3bcba5848f6e1fa2bf3"
  end

  # "This repository was archived by the owner on Apr 12, 2026. It is now read-only."
  disable! date: "2027-04-12", because: :repo_archived

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "openjdk" => :build
  depends_on "emacs"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "gperf" => :build
  uses_from_macos "m4" => :build

  deny_network_access!

  def install
    # Fix compile with newer Clang
    ENV.append_to_cflags "-Wno-implicit-function-declaration" if DevelopmentTools.clang_build_version >= 1403
    # autoconf 2.73 selects C23, where `bool` is a keyword that `src/nconfig.h` redefines
    ENV["ac_cv_prog_cc_c23"] = "no"

    ENV["JAVA_HOME"] = formula_opt_prefix("openjdk")
    # nesc is unable to build in parallel because multiple emacs instances
    # lead to locking on the same file
    ENV.deparallelize

    system "./Bootstrap"
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"Check.nc").write <<~NESC
      interface Check {
        command void check();
        event void checkDone(int result);
      }
    NESC

    (testpath/"Module.nc").write <<~NESC
      generic module Module(int result) {
        provides interface Check;
      } implementation {
        command void Check.check() {
          signal Check.checkDone(result);
        }
      }
    NESC

    (testpath/"TestP.nc").write <<~NESC
      #include <stdio.h>

      module TestP {
        uses interface Check as Yes;
        uses interface Check as No;
      } implementation {
        int main() @C() @spontaneous() {
          call Yes.check();
          call No.check();
          return 0;
        }

        event void Yes.checkDone(int result) {
          printf("Yes -> %d\\n", result);
        }

        event void No.checkDone(int result) {
          printf("No -> %d\\n", result);
        }
      }
    NESC

    (testpath/"test.nc").write <<~NESC
      configuration test {
      } implementation {
        components TestP;
        components new Module(6 * 7 == 42) as YesM;
        components new Module(6 * 7 != 42) as NoM;

        TestP.Yes -> YesM;
        TestP.No -> NoM;
      }
    NESC

    system lib/"ncc/nesc1", "-fnesc-separator=__",
           "-fnesc-include=#{lib}/ncc/deputy_nodeputy",
           "-fnesc-include=#{lib}/ncc/nesc_nx",
           "test.nc", "-o", "test.c"
    assert_match "TestP__Yes__checkDone", (testpath/"test.c").read

    system ENV.cc, "test.c", "-o", "test"
    assert_equal "Yes -> 1\nNo -> 0\n", shell_output("./test")
  end
end
