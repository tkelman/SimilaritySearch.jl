#  Copyright 2016 Eric S. Tellez <eric.tellez@infotec.mx>
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http:#www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

export Kvp, kvprefs

mutable struct Kvp{T, D} <: Index
    db::Array{T,1}
    dist::D
    refs::Array{T,1}
    sparsetable::Array{Array{Item}}
end

function Kvp{T, D}(db::Array{T,1}, dist::D, k::Int, refList::Array{Int,1})
    info("Kvp, refs=$(typeof(db)), k=$(k), numrefs=$(length(refList)), dist=$(dist)")
    sparsetable = Array(Array{Item}, 0)
    refs = [db[x] for x in refList]
    for i=1:length(db)
        if (i % 10000) == 0
            info("advance $(i)/$(length(db))")
        end
        row = kvprefs(db[i], refs, k, dist)
        # println(row)
        push!(sparsetable, row)
    end

    return Kvp(db, dist, refs, sparsetable)
end

function Kvp{T, D}(db::Array{T,1}, dist::D, k::Int, numrefs::Int)
    refs = rand(1:length(db), numrefs)
    Kvp(db, dist, k, refs)
end

function kvprefs{T, D}(obj::T, refs::Array{T,1}, k::Int, dist::D)
    near = KnnResult(k)
    far = KnnResult(k)
    for (refID, ref) in enumerate(refs)
        d = dist(obj, ref)
        push!(near, refID, d)
        push!(far, refID, -d)
    end

    row = Array(Item, k+k)
    for (j, item) in enumerate(near)
        row[j] = item
    end

    for (j, item) in enumerate(far)
        item.dist = -item.dist
        row[k+j] = item
    end

    return row
end

function search{T, R <: Result}(index::Kvp{T}, q::T, res::R)
    # for i in range(1, length(index.db))
    d::Float64 = 0.0
    qI = [index.dist(q, piv) for piv in index.refs]

    for i = 1:length(index.db)
        obj::T = index.db[i]
        objSparseRow::Array{Item,1} = index.sparsetable[i]

        discarded::Bool = false
        @inbounds for item in objSparseRow
            pivID = item.objID
            dop = item.dist
            if abs(dop - qI[pivID]) > covrad(res)
                discarded = true
                break
            end
        end
        if discarded
            continue
        end
        d = index.dist(q, obj)
        push!(res, i, d)
    end

    return res
end

function search{T}(index::Kvp{T}, q::T)
    return search(index, q, NnResult())
end

function push!{T}(index::Kvp{T}, obj::T)
    push!(index.db, obj)
    row = kvprefs(obj, index.refs, index.k, index.dist)
    push!(index.sparsetable, row)
    return length(index.db)
end
