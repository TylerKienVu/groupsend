import { View, Text, StyleSheet } from 'react-native';

export default function GroupCreationScreen() {
  return (
    <View style={styles.container}>
      <Text>Create Group</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
