import pickle

if __name__ == '__main__':
    file = "data/test_map_cargo.pkl"
    with open(file, "rb") as f:
        data = pickle.load(f)

    # prefix = '/home/dataset/chenwei/work/agent/SolEval/'
    # replacement = ''
    # new_data = {}
    # for k, v in data.items():
    #     new_key = k.replace(prefix, replacement)
    #     new_value = v.replace(prefix, replacement)

    #     new_data[new_key] = new_value

    print(data)
    # print(new_data)
    # with open(file, 'wb') as f:
    #     pickle.dump(new_data, f)
