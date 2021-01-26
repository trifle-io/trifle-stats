# Driver

Driver is a wrapper class that persists and retrieves values from backend. It needs to implement:
- `inc(key:, **values)` method to store values
- `get(key:)` method to retrieve values

## Packer Mixin

Some databases cannot store nested hashes/values. Or they cannot perform increment on nested values that does not exist. For this reason you can use Packer mixin that helps you convert values to dot notation.

```ruby
class Sample
  include Trifle::Ruby::Mixins::Packer
end

values = { a: 1, b: { c: 22, d: 33 } }
=> {:a=>1, :b=>{:c=>22, :d=>33}}

packed = Sample.pack(hash: values)
=> {"a"=>1, "b.c"=>22, "b.d"=>33}

Sample.unpack(hash: packed)
=> {"a"=>1, "b"=>{"c"=>22, "d"=>33}}
```
