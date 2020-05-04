require "./spec_helper"

describe Hash do
  it "merges 2 basic hashes" do
    a = {
      "a" => 1,
    }

    b = {
      "b" => 2,
    }

    result = {
      "a" => 1,
      "b" => 2,
    }

    a.deep_merge(b).should eq(result)
  end

  it "merges nested hashes" do
    a = {
      "a" => {
        "b" => 2,
      },
    }

    b = {
      "c" => 3,
    }

    result = {
      "a" => {
        "b" => 2,
      },
      "c" => 3,
    }

    a.deep_merge(b).should eq(result)
  end

  it "merges hashes" do
    a = {
      "a" => {
        "b" => 2,
      },
    }

    b = {
      "a" => {
        "c" => 3,
      },
      "d" => 4,
    }

    result = {
      "a" => {
        "b" => 2,
        "c" => 3,
      },
      "d" => 4,
    }
    a.deep_merge(b).should eq(result)
  end

  it "overwrites keys with same name if not a hash" do
    a = {
      "a" => 1,
    }

    b = {
      "a" => 2,
    }

    result = {
      "a" => 2,
    }

    a.deep_merge(b).should eq(result)
  end

  it "overwrites keys with same name without children when nested" do
    a = {
      "a" => {
        "b" => 2,
      },
    }

    b = {
      "a" => {
        "b" => 3,
      },
      "d" => 4,
    }

    result = {
      "a" => {
        "b" => 3,
      },
      "d" => 4,
    }

    a.deep_merge(b).should eq(result)
  end

  it "overwrites keys with same name without children when nested but preserves siblings" do
    a = {
      "a" => {
        "b" => 2,
        "c" => 2,
      },
    }

    b = {
      "a" => {
        "c" => 3,
      },
      "d" => 4,
    }

    result = {
      "a" => {
        "b" => 2,
        "c" => 3,
      },
      "d" => 4,
    }

    a.deep_merge(b).should eq(result)
  end

  it "overwrites keys with same name if only one is a hash" do
    a = {
      "a" => 1,
    }

    b = {
      "a" => {
        "b" => 2,
      },
    }

    result = {
      "a" => {
        "b" => 2,
      },
    }

    a.deep_merge(b).should eq(result)
  end

  it "bang merges 2 basic hashes of the same type" do
    a = {
      "a" => 1,
    }

    b = {
      "b" => 2,
    }

    result = {
      "a" => 1,
      "b" => 2,
    }

    a.deep_merge!(b).should eq(result)
  end

  it "bang merges nested hashes of the same type" do
    a = {
      "a" => {
        "b" => 2,
      },
    }

    b = {
      "a" => {
        "c" => 3,
      },
    }

    result = {
      "a" => {
        "b" => 2,
        "c" => 3,
      },
    }

    a.deep_merge!(b).should eq(result)
  end

  it "bang overwrites keys with same name if not a hash and of the same type" do
    a = {
      "a" => 1,
    }

    b = {
      "a" => 2,
    }

    result = {
      "a" => 2,
    }

    a.deep_merge!(b).should eq(result)
  end

  it "bang overwrites keys with same name without children when nested and of the same type" do
    a = {
      "a" => {
        "b" => 2,
      },
    }

    b = {
      "a" => {
        "b" => 3,
      },
    }

    result = {
      "a" => {
        "b" => 3,
      },
    }

    a.deep_merge!(b).should eq(result)
  end

  it "bang overwrites keys with same name without children when nested and of the same type, but preserves siblings" do
    a = {
      "a" => {
        "b" => 2,
        "c" => 2,
      },
      "d" => 4,
    }

    b = {
      "a" => {
        "c" => 3,
      },
      "e" => 5,
    }

    result = {
      "a" => {
        "b" => 2,
        "c" => 3,
      },
      "d" => 4,
      "e" => 5,
    }

    a.deep_merge!(b).should eq(result)
  end

end
