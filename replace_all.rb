#!/usr/bin/ruby
# coding: utf-8
#
def help()
print <<EOT
usage: replace_all.rb [option]

*warning*       this script overwrite your files written in configuration file.
                please backup before execute this script.

option:
-h              print this message.
-f file         read replace configuration from 'file'
                instead of ./replace.conf file.

configuration file sample:
    replace.conf
    #-------------------------------    # comment.
    <replace_files>                     # replace file list.
    file1.cpp
    file2.cpp
    </replace_files>
    <replace_items>                     # list of search text and replace text pair.
    SLONG             sint32_t          # separate the search text and
    ULONG             uint32_t          # the replace text by whitespace.
    "signed long"     sint32_t          # quote the text that has white space.
    "unsigned long"   uint32_t
    LONGLONG          "long long"
    </replace_items>
    #-------------------------------
EOT
end

#help
#exit

# 空白文字で区切られた文字列を取得する。
# ただし "" で括られた文字列は空白も文字列の一部と見なす。
#
# "" で括られた中に " を入れたい場合は \" とする。 \ を入れたいときは
# \\ とする。 "" がちゃんと2個組に書かれているかはチェックしていないそ
# の場合は、最初の " から最後まで一つの文字列と見なす。 "" で囲まれて
# いない文字列のなかに " と \ が出てきたら特別な意味はないただの文字そ
# のものとして扱う。
#
# 戻り値は String の配列
def split_quoted_string(str)
  arr = []
  text = ""
  mode = :normal
  mode_stack = []
  
  str.strip.split("").each do |ch|
    if mode == :normal
      if ch == "\""
        # text がカラのときだけ :quoted へ遷移する
        if text.empty?
          mode_stack.push(mode)
          mode = :quoted
          next
        end
      elsif ch =~ /\s/
        mode = :text_ended
        next
      end
      text += ch
    elsif mode == :escaped
      text += ch
      mode = mode_stack.pop()
    elsif mode == :quoted
      if ch == "\\"
        mode_stack.push(mode)
        mode = :escaped
        next
      elsif ch == "\""
        mode = :text_ended
        next
      end
      text += ch
    elsif mode == :text_ended
      if ! text.empty?
        arr.push(text)
        text = ""
      end
      mode = :normal
      redo                                      # next ではなく redo
    end
  end
  if ! text.empty?
    arr.push(text)
    text = ""
  end
  return arr
end
#p split_quoted_string("Hello World")
#p split_quoted_string("\"Hello World\" HELLO_WORLD")
#p split_quoted_string("\"HELLO_WORLD\" \"Hello World AAA\"")
#p split_quoted_string("HELLO\"WORLD\" \"Hello World BBB\"")
#p split_quoted_string("HELLO\"WORLD\" Hello World CCC")
#p split_quoted_string("\"HELLO_WORLD Hello World CCC")
#p split_quoted_string("HELLO_WORLD \"Hello World CCC")
#p split_quoted_string("HELLO\"WORLD Hello World CCC")
#p split_quoted_string("HELLO \"WORLD\" Hello World CCC")
#exit

# 検索、置換ペアのパース
def parse_item(str)
  # 最初の二つだけ返す
  key, rep = split_quoted_string(str);
  return key, rep
end
#p split_quoted_string("aaa bbb ccc")
#p parse_item("aaa bbb ccc")
#exit

# replace.conf の読み取り
# 設定値をいれたハッシュを返す
def load_config(config_filename)
  config = {}
  files = []
  items = []

  mode = :none
  File.readlines(config_filename).each do |line|
    #p line
    if mode == :none
      if line =~ /^\<replace_files\>/
        mode = :getfiles
        next
      elsif line =~ /^\<replace_items\>/
        mode = :getitems
        next
      end
    elsif mode == :getfiles
      if line =~ /^\<\/replace_files\>/
        mode = :none
        next
      end
      # ファイル名の取り込み
      filename = line.strip
      if ! filename.empty?
        files.push(filename)
      end
    elsif mode == :getitems
      if line =~ /^\<\/replace_items\>/
        mode = :none
        next
      end
      # 検索キーと置換文字列の取得
      key, rep = parse_item(line)
      #p key, rep
      if (key != nil and !key.empty?) and (rep != nil  and !rep.empty?)
        items.push([key, rep])
      end
    end
  end
  config[:config_files] = files
  config[:config_items] = items
  return config
end
#p load_config("./replace.conf")



# ファイルを読み込んですべての置換を実施
def main
  config = load_config("./replace.conf")

  if config[:config_files].empty?
    print "replace configuration error (file notfound).\n"
    exit 1
  end
  if config[:config_items].empty?
    print "replace configuration error (search key not found).\n"
    exit 1
  end

  config[:config_files].each do |filename|
    if ! FileTest.exist?(filename)
      print "file \"#{filename}\" not found.\n"
      exit 1
    end
    lines = File.readlines(filename)
    config[:config_items].each do |item|
      lines = lines.map do |line|
        key, rep = item[0,2]
        line.gsub(/#{key}/, "#{rep}")
      end
    end
    # !!! 既存のファイルを上書き !!!
    ofile = File.open(filename, "w")
    lines.each do |line|
      ofile.print(line)
    end
    ofile.close
    #p lines
  end
end

# メイン実行
main

